pragma solidity >=0.6.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWarItemSystem.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract PolkaWarNFTAirdrop is Ownable, ReentrancyGuard, VRFConsumerBase {
    string public name = "PolkaWar: PolkaWarNFTAirdrop";
    uint256 public tokenCounter;
    PolkaWarItemSystem itemSystem;
    //list airdrop item

    mapping(uint256 => string) public airdropItems;//id - uri

    // add other things
    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => string) public requestIdToTokenURI;
    mapping(uint256 => Breed) public tokenIdToBreed;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    event requestedGetAirdrop(bytes32 indexed requestId);

    bytes32 internal keyHash;
    uint256 internal fee;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash,
       PolkaWarItemSystem _itemSystem
    ) public VRFConsumerBase(_VRFCoordinator, _LinkToken) {
        tokenCounter = 0;
        keyHash = _keyhash;
        fee = 0.1 * 10**18;
        LINK = LinkTokenInterface(_LinkToken);
        itemSystem=_itemSystem;
    }
    
    public initItems(string memory imageHash,string memory uriHash) public onlyOwner{
        airdropItems[imageHash]=uriHash;
    }

    public getItemURI(string memory hash) public view returns(string){
        return airdropItems[hash];
    }

    function getAirdrop(uint256 userProvidedSeed)
        public
        returns (bytes32)
    {
        require(LINK.balanceOf(address(this)) > fee, "Not enough LINK - deposit LINK to contract first");
        uint256 seed = uint256(keccak256(abi.encode(userProvidedSeed, blockhash(block.number)))); 
        bytes32 requestId = requestRandomness(keyHash, fee, seed);
        requestIdToSender[requestId] = msg.sender;
        requestIdToTokenURI[requestId] = tokenURI;
        emit requestedGetAirdrop(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        address dogOwner = requestIdToSender[requestId];
        string memory tokenURI = requestIdToTokenURI[requestId];
        uint256 newItemId = tokenCounter;
        _safeMint(dogOwner, newItemId);
        _setTokenURI(newItemId, tokenURI);
        Breed breed = Breed(randomNumber % 3);
        tokenIdToBreed[newItemId] = breed;
        requestIdToTokenId[requestId] = newItemId;
        tokenCounter = tokenCounter + 1;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _setTokenURI(tokenId, _tokenURI);
    }
}
