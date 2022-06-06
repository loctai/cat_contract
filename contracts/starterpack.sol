// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./nft.sol";
import "./userpool.sol";

contract CAT_StarterPack is
    ERC721,
    AccessControlEnumerable,
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // ONLY ALLOW BUSD
    using SafeERC20 for IERC20;
    IERC20 public BUSD;
    IERC20 public CAT;
    CAT_NFT public FactoryNFT;
    UserPool public Pool;

    // EVENT

    event BuyStarterPack(uint256 indexed tokenId, address addressWallet);

    event OpenPackSuccess(
        uint256 packId,
        address addressWallet,
        address contractCreate
    );

    // STATE
    mapping(address => bool) public approvalWhitelists;
    mapping(uint256 => bool) public lockedTokens;
    mapping(uint256 => bool) public isOpen;
    mapping(address => uint256) public whitelistGuild;

    string private _baseTokenURI;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public totalStarterPack;
    uint256 public totalSoldStarterPack = 0;
    uint256 public priceStarterPack;

    uint256 public totalItemInPack;
    uint256 public totalCATInPack;

    uint256 public percentStarterPack = 6000; // 60%

    bool public saleEnded;
    bool public isPause;

    constructor() ERC721("Aethr Pack", "CATP") {}

    function initialize(
        string memory baseTokenURI,
        address _BUSD,
        address _CAT,
        address _Pool,
        address _Factory,
        uint256 _Price,
        uint256 _TotalItem,
        uint256 _TotalCAT
    ) public onlyOwner {
        BUSD = IERC20(_BUSD);
        CAT = IERC20(_CAT);
        Pool = UserPool(_Pool);
        FactoryNFT = CAT_NFT(_Factory);
        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        CAT.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );

        priceStarterPack = _Price;
        totalItemInPack = _TotalItem;
        totalCATInPack = _TotalCAT;
        _baseTokenURI = baseTokenURI;
        _setupRole(MINTER_ROLE, msg.sender);
    }

    modifier checkOpenPack(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "Box Open : must have owner role to open"
        );
        require(isPause == false, "Maintain");
        require(isOpen[tokenId] == false, "Box Open : box is opened");
        require(!lockedTokens[tokenId], "Box Open : box is locked");
        require(
            FactoryNFT.hasRole(MINTER_ROLE, address(this)) == true,
            "Box Open : is error of Pack Contract"
        );
        _;
    }

    function setMinterRole(address _address) public onlyOwner {
        _setupRole(MINTER_ROLE, _address);
    }

    function mintStarterPack(address to) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Must have minter role to mint"
        );
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(!_exists(newItemId), "Pack Payment: must have unique tokenId");
         _mint(to, newItemId);
        emit BuyStarterPack(newItemId, to);
    }

    function claimGuildPack(uint256 totalPack) public nonReentrant {
        require(totalPack <= whitelistGuild[msg.sender]);
        require(isPause == false, "Maintain");
        for (uint256 index = 0; index < totalPack; index++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();

            require(
                !_exists(newItemId),
                "Pack Payment: must have unique tokenId"
            );
            require(
                whitelistGuild[msg.sender] > 0,
                "Box Payment: Invalid balance of pack in pool "
            );
            whitelistGuild[msg.sender] = whitelistGuild[msg.sender] - 1;
            _mint(msg.sender, newItemId);
            isOpen[newItemId] = false;
            emit BuyStarterPack(newItemId, msg.sender);
        }
    }

    function openStarterPack(uint256 boxId) public checkOpenPack(boxId) {
        for (uint256 index = 0; index < totalItemInPack; index++) {
            FactoryNFT.mint(msg.sender);
        }

        uint256 totalPool = calculateFee(priceStarterPack, percentStarterPack);
        Pool.augmentPoolBUSD(msg.sender, totalPool);
        Pool.augmentPoolCAT(msg.sender, totalCATInPack);
        isOpen[boxId] = true;

        emit OpenPackSuccess(boxId, msg.sender, address(FactoryNFT));
    }

    function setTotalItemInPack(uint256 _total) public onlyOwner {
        totalItemInPack = _total;
    }

    function setTotalCATInPack(uint256 _total) public onlyOwner {
        totalCATInPack = _total;
    }

    /**
     * @dev caculateDiscount;
     */
    function calculateFee(uint256 amount, uint256 _feePercent)
        public
        pure
        returns (uint256)
    {
        return (amount / 10000) * _feePercent;
    }

    function setPrice(uint256 price) public onlyOwner {
        priceStarterPack = price;
    }

    function setPause(bool status) public onlyOwner {
        isPause = status;
    }

    function setWhiteListGuild(address walletAddress, uint256 totalPack)
        public
        onlyOwner
    {
        whitelistGuild[walletAddress] = totalPack;
    }

    function unsoldPack() public view returns (uint256) {
        return uint256(totalStarterPack - totalSoldStarterPack);
    }

    /**
     * @dev Lock token to use in game or for rental
     */
    function lock(uint256 tokenId) public {
        require(
            approvalWhitelists[msg.sender],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(!lockedTokens[tokenId], "Token has already locked");
        lockedTokens[tokenId] = true;
    }

    /**
     * @dev Unlock token to use blockchain or sale on marketplace
     */
    function unlock(uint256 tokenId) public {
        require(
            approvalWhitelists[msg.sender],
            "Must be valid approval whitelist"
        );
        require(_exists(tokenId), "Must be valid tokenId");
        require(lockedTokens[tokenId], "Token has already unlocked");
        lockedTokens[tokenId] = false;
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (approvalWhitelists[operator] == true) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev Allow operation to reduce gas fee.
     */
    function addApprovalWhitelist(address proxy) public onlyOwner {
        require(
            approvalWhitelists[proxy] == false,
            "GameNFT: invalid proxy address"
        );

        approvalWhitelists[proxy] = true;
    }

    /**
     * @dev Remove operation from approval list.
     */
    function removeApprovalWhitelist(address proxy) public onlyOwner {
        approvalWhitelists[proxy] = false;
    }

    /**
     * @dev Get lock status
     */
    function isLocked(uint256 tokenId) public view returns (bool) {
        return lockedTokens[tokenId];
    }

    /**
     * @dev Set token URI
     */
    function updateBaseURI(string calldata baseTokenURI) public onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev See {IERC165-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        require(!lockedTokens[tokenId], "Can not transfer locked token");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Update baseURI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
