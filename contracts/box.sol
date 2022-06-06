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

contract CAT_Box is
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
    UserPool public Pool;
    CAT_NFT public FactoryNFT;

    // EVENT
    event ClaimBoxFree(uint256 indexed tokenId, address addressWalletClaim);

    event BuyBox(uint256 indexed tokenId, address addressWallet);

    event BuyBoxPremium(uint256 indexed tokenId, address addressWallet);

    event BuyStarterPack(uint256 indexed tokenId, address addressWallet);

    event OpenBoxSuccess(
        uint256 tokenId,
        address addressWallet,
        address contractCreate
    );

    event ClaimSucces(
        uint256 totalClaim,
        address addressWallet,
        address sender
    );

    // STATE
    mapping(address => bool) public approvalWhitelists;
    mapping(uint256 => bool) public lockedTokens;
    mapping(address => bool) public claimFree;

    string private _baseTokenURI;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public totalBox;
    uint256 public totalSold;
    uint256 public priceBox;

    uint256 public totalBoxPremium;
    uint256 public totalSoldPremium;
    uint256 public priceBoxPremium;

    uint256 public startDate = 1641644620;
    uint256 public endDate = 1791644620;

    bool public saleEnded;

    address public poolAddress;

    constructor(
        string memory baseTokenURI,
        address _BUSD,
        address _CATToken,
        address _Pool
    ) ERC721("Aethr Box", "CATB") {
        BUSD = IERC20(_BUSD);
        CAT = IERC20(_CATToken);
        Pool = UserPool(_Pool);

        CAT.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        _baseTokenURI = baseTokenURI;
        _setupRole(MINTER_ROLE, _msgSender());
    }

    modifier checkSaleRequirements(address _msgSender) {
        uint256 allowToPayAmount = BUSD.allowance(_msgSender, address(this));
        require(
            allowToPayAmount >= priceBox,
            "Box Payment: Invalid token allowance"
        );
        require(
            BUSD.balanceOf(_msgSender) >= priceBox,
            "Box Payment: Invalid balanceOf"
        );
        require(
            block.timestamp >= startDate && block.timestamp < endDate,
            "Sale time passed"
        );
        require(unsoldBox() > 0, "Insufficient buy amount");
        _;
    }

    modifier checkSalePremiumRequirements(address _msgSender) {
        uint256 allowToPayAmount = CAT.allowance(_msgSender, address(this));
        require(
            allowToPayAmount >= priceBoxPremium,
            "Box Payment: Invalid token allowance"
        );
        require(
            CAT.balanceOf(_msgSender) >= priceBoxPremium,
            "Box Payment: Invalid balanceOf"
        );
        require(
            block.timestamp >= startDate && block.timestamp < endDate,
            "Sale time passed"
        );
        require(unsoldBoxPremium() > 0, "Insufficient buy amount");
        _;
    }

    modifier checkClaimBoxRequirements(address addressClaim) {
        require(
            claimFree[addressClaim] != true,
            "Box Claim: Only once per address"
        );
        _;
    }

    modifier checkOpenBox(uint256 tokenId) {
        require(
            ownerOf(tokenId) == _msgSender(),
            "Box Open : must have owner role to open"
        );
        require(!lockedTokens[tokenId], "Box Open : box is locked");
        require(
            FactoryNFT.hasRole(MINTER_ROLE, address(this)) == true,
            "Box Open : is error of Box Contract"
        );
        _;
    }

    function boxFree()
        public
        checkClaimBoxRequirements(_msgSender())
        nonReentrant
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(!_exists(newItemId), "Box Payment: must have unique tokenId");
        claimFree[_msgSender()] = true;
        _mint(_msgSender(), newItemId);
        emit ClaimBoxFree(newItemId, _msgSender());
    }

    function boxBasic(address to)
        public
        virtual
        checkSaleRequirements(_msgSender())
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(!_exists(newItemId), "Box Payment: must have unique tokenId");
        _mint(to, newItemId);
        BUSD.transferFrom(_msgSender(),address(Pool), priceBox);
        Pool.augmentPoolBUSD(_msgSender(), priceBox);
        emit BuyBox(newItemId, _msgSender());
    }

    function boxPremium(address to)
        public
        virtual
        checkSalePremiumRequirements(_msgSender())
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(!_exists(newItemId), "Box Payment: must have unique tokenId");
        CAT.transferFrom(_msgSender(), address(this), priceBoxPremium);
        _mint(to, newItemId);
        emit BuyBoxPremium(newItemId, _msgSender());
    }

    function openBox(uint256 boxId) public checkOpenBox(boxId) {
        FactoryNFT.mint(_msgSender());
        emit OpenBoxSuccess(boxId, _msgSender(), address(FactoryNFT));
    }

    /**
     * @dev Set BUSD
     */
    function setBUSD(address _addressBUSD) public onlyOwner {
        BUSD = IERC20(_addressBUSD);
    }

    /**
     * @dev Set CAT
     */
    function setAddressCAT(address _addressCAT) public onlyOwner {
        CAT = IERC20(_addressCAT);
    }

    /**
     * @dev Set price box
     */
    function setPriceBox(uint256 _price) public onlyOwner {
        priceBox = _price;
    }

    /**
     * @dev Set price box
     */
    function setPriceBoxPremium(uint256 _price) public onlyOwner {
        priceBoxPremium = _price;
    }

    /**
     * @dev Set start date
     */
    function setStartDate(uint256 _startDate) public onlyOwner {
        startDate = _startDate;
    }

    /**
     * @dev Set end date
     */
    function setEndDate(uint256 _endDate) public onlyOwner {
        endDate = _endDate;
    }

    /**
     * @dev set factory
     */
    function setFactoryNFT(address factory) public onlyOwner {
        FactoryNFT = CAT_NFT(factory);
    }

    /**
     * @dev set total box
     */
    function setTotalBox(uint256 _totalBox) public onlyOwner {
        totalBox = _totalBox;
    }

    /**
     * @dev set total box premium
     */
    function setTotalBoxPremium(uint256 _totalBox) public onlyOwner {
        totalBoxPremium = _totalBox;
    }

    function unsoldBox() public view returns (uint256) {
        return uint256(totalBox - totalSold);
    }

    function unsoldBoxPremium() public view returns (uint256) {
        return uint256(totalBoxPremium - totalSoldPremium);
    }

    /**
     * @dev Lock token to use in game or for rental
     */
    function lock(uint256 tokenId) public {
        require(
            approvalWhitelists[_msgSender()],
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
            approvalWhitelists[_msgSender()],
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