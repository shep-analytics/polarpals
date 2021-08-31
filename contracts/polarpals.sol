// SPDX-License-Identifier: MIT



pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract PolarPals is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {

    using Address for address payable;
    using SafeMath for uint256;

    uint256 public constant MAX_PALS = 10000;
    uint256 public constant MAX_PURCHASE = 6;
    uint256 public constant AMOUNT_RESERVED = 120;
    uint256 public constant PAL_PRICE = 9E16; // 0.09ETH
    uint256 public constant RENAME_PRICE = 9E15; // 0.009ETH
    string public constant TOKEN_URI_BASE = "https://fluf-site.vercel.app/api/token/"; 


    enum State {
        Setup,
        PreParty,
        Party
    }

    mapping(address => uint256) private _authorised;

    mapping(uint256 => bool) private _nameChanged;


    State private _state;


    string private _immutableIPFSBucket;
    string private _mutableIPFSBucket;

    uint256 _nextTokenId;
    uint256 _startingIndex;


      //Credit to deploying address
    function setStartingIndexAndMintReserve(address reserveAddress) public {
        require(_startingIndex == 0, "Starting index is already set.");
        
        _startingIndex = uint256(blockhash(block.number - 1)) % MAX_PALS;
   
        // Prevent default sequence
        if (_startingIndex == 0) {
            _startingIndex = _startingIndex.add(1);
        }

        _nextTokenId = _startingIndex;


        for(uint256 i = 0; i < AMOUNT_RESERVED; i++) {
            _safeMint(reserveAddress, _nextTokenId); 
            _nextTokenId = _nextTokenId.add(1).mod(MAX_PALS); 
        }
    }

	event NameAndDescriptionChanged(uint256 indexed _tokenId, string _name, string _description);

  
    constructor() ERC721("PolarPals","PALS") {
        _state = State.Setup;
    }

    function setImmutableIPFSBucket(string memory immutableIPFSBucket_) public onlyOwner {
        require(bytes(_immutableIPFSBucket).length == 0, "This IPFS bucket is immutable and can only be set once.");
        _immutableIPFSBucket = immutableIPFSBucket_;
    }

    function setMutableIPFSBucket(string memory mutableIPFSBucket_) public onlyOwner {
        _mutableIPFSBucket = mutableIPFSBucket_;
    }


    function changeNameAndDescription(uint256 tokenId, string memory newName, string memory newDescription) public payable {
        address owner = ERC721.ownerOf(tokenId);

        require(
            _msgSender() == owner,
            "This isn't your PolarPal."
        );

        uint256 amountPaid = msg.value;

        if(_nameChanged[tokenId]) {
            require(amountPaid == RENAME_PRICE, "It costs to create a new identity.");
        } else {
            require(amountPaid == 0, "First time's free friend.");
            _nameChanged[tokenId] = true;
        }

        emit NameAndDescriptionChanged(tokenId, newName, newDescription);
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
 


    function baseTokenURI() virtual public view returns (string memory) {
        return TOKEN_URI_BASE;
    }

    function state() virtual public view returns (State) {
        return _state;
    }

    function immutableIPFSBucket() virtual public view returns (string memory) {
        return _immutableIPFSBucket;
    }

    function mutableIPFSBucket() virtual public view returns (string memory) {
        return _mutableIPFSBucket;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {

        return string(abi.encodePacked(baseTokenURI(), Strings.toString(tokenId)));
 
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function startPreParty() public onlyOwner {
        require(_state == State.Setup);
        _state = State.PreParty;
    }

    function setStateToParty() public onlyOwner {
        _state = State.Party;
    }


    function mintPAL(address human, uint256 amountOfPALs) public nonReentrant payable virtual returns (uint256) {

        require(_state != State.Setup, "PolarPals aren't ready yet!");
        require(amountOfPALs <= MAX_PURCHASE, "Hey, that's too many PolarPals. Save some for the rest of us!");

        require(totalSupply().add(amountOfPALs) <= MAX_PALS, "Sorry, there's not that many PolarPals left.");
        require(PAL_PRICE.mul(amountOfPALs) <= msg.value, "Hey, that's not the right price.");


        if(_state == State.PreParty) {
            require(_authorised[human] >= amountOfPALs, "Hey, you're not allowed to buy this many PolarPals during the pre-party.");
            _authorised[human] -= amountOfPALs;
        }

        uint256 firstPalRecieved = _nextTokenId;

        for(uint i = 0; i < amountOfPALs; i++) {
            _safeMint(human, _nextTokenId); 
            _nextTokenId = _nextTokenId.add(1).mod(MAX_PALS); 
        }

        return firstPalRecieved;

    }

    function withdrawAllEth(address payable payee) public virtual onlyOwner {
        payee.sendValue(address(this).balance);
    }


    function authorisePal(address human, uint256 amountOfPALs)
        public
        onlyOwner
    {
      _authorised[human] += amountOfPALs;
    }


    function authorisePalBatch(address[] memory humans, uint256 amountOfPALs)
        public
        onlyOwner
    {
        for (uint8 i = 0; i < humans.length; i++) {
            authorisePal(humans[i], amountOfPALs);
        }
    }

}