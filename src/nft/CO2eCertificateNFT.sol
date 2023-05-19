// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IERC4906.sol";
import "../fractional/ERC20TokenCenter.sol";
import "./UUIDGenerator.sol";
import "./TransferFromHelper.sol";

contract CO2eCertificateNFT is Ownable, ReentrancyGuard, IERC4906, ERC721 {    
    /**
     * @dev Because the carbon credit certificates generated from this contract
     *      are all issued by a single platform, it does make sense to let both
     *      `_sourceMaps` and `_issueByMaps` shrink into two constant logical
     *      structures `CertSource` and `CertIssueBy`. BTW, type `immutable`
     *      does not support `struct`.
     */
    /******************************** Constant ********************************/
    uint256 public immutable certSourceId;
    uint256 public immutable certIssueById;
    bytes32 public immutable certSource;
    bytes30 public immutable certIssueBy;
    uint16  public immutable certIssueByRatio;
    ERC20TokenCenter public immutable erc20TokenCenter;
    UUIDGenerator public immutable uuidGenerator;
    
    /******************************* Structure ********************************/
    struct TokenInfo {
        string certId;     // 證書 ID（至多三十二位元組）
        uint256 sourceId;  // 證書來源 ID（需再查詢 `getSourceList()`）
        uint256 issueById; // 簽發機構 ID（需再查詢 `getIssueByList()`）
        uint64 weight;     // 碳權當量（公噸）
        uint256 date;      // 代幣鑄造時間戳記
    }
    
    struct TokenInfoLiterally {
        string certId;  // 證書 ID（至多三十二位元組）
        string source;  // 證書來源字串（至多三十二位元組）
        string issueBy; // 簽發機構字串（至多三十位元組）
        uint64 weight;  // 碳權當量（公噸）
        uint256 date;   // 代幣鑄造時間戳記
    }
    
    struct TokenData {
        bytes32 certId;
        uint192 date;
        uint64  weight;
    }
    
    struct CertSource {
        bytes32 source; // 證書來源字串（至多三十二位元組）
    }
    
    struct CertIssueBy {
        bytes30 issueBy; // 簽發機構字串（至多三十位元組）
        uint16  ratio; // `weight` * `ratio` = Carbon Credit FTs `supply` amount
    }
    
    /***************************** State veriable *****************************/
    uint256 public currTokenId;
    uint256 public minSwapAmount;
    mapping(uint256 => TokenData) private _tokenURIs; // `tokenId` => TokenData
    
    /****************************** Constructor *******************************/
    constructor(
        string memory name,
        string memory symbol,
        string memory source,
        string memory issueBy,
        uint16 ratio,
        address tokenCenter,
        address uuidGen
    ) ERC721(name, symbol) {
        require(bytes(source).length != 0, "Forbid empty `source`");
        require(bytes(source).length < 33, "The length of `source` <= 32 bytes");
        
        require(bytes(issueBy).length != 0, "Forbid empty `issueBy`");
        require(bytes(issueBy).length < 31, "The length of `issueBy` <= 30 bytes");
        require(ratio != 0, "Conversion `ratio` must be non-zero");
        
        minSwapAmount    = 1000;
        certSourceId     = 0;
        certIssueById    = 0;
        certSource       = bytes32(abi.encodePacked(source));
        certIssueBy      = bytes30(abi.encodePacked(issueBy));
        certIssueByRatio = ratio;
        erc20TokenCenter = ERC20TokenCenter(tokenCenter);
        uuidGenerator    = UUIDGenerator(uuidGen);
    }
    
    /************************** Public read function **************************/
    function getSourceList() external view returns (string[] memory){
        string[] memory sourceList = new string[](1);
        sourceList[0] = string(bytes.concat(certSource));
        return sourceList;
    }
    
    function getIssueByList() external view returns (string[] memory){
        string[] memory issueByList = new string[](1);
        issueByList[0] = string(bytes.concat(certIssueBy));
        return issueByList;
    }

    function getTokenInfo(uint256 tokenId) external view returns (TokenInfo memory){
        require(ERC721._exists(tokenId), "Cannot get non-existent token");
        
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return TokenInfo(
            string(bytes.concat(tokenData.certId)),
            certSourceId,
            certIssueById,
            tokenData.weight,
            (((block.timestamp>>192)<<192) + uint256(tokenData.date))
        );
    }
    
    function getTokenInfoLiterally(
        uint256 tokenId
    ) external view returns (TokenInfoLiterally memory) {
        require(ERC721._exists(tokenId), "Cannot get non-existent token");
        
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return TokenInfoLiterally(
            string(bytes.concat(tokenData.certId)),
            string(bytes.concat(certSource)),
            string(bytes.concat(certIssueBy)),
            tokenData.weight,
            (((block.timestamp>>192)<<192) + uint256(tokenData.date))
        );
    }
    
    function getRatio(uint256 issueById) external view returns (uint16) {
        return certIssueByRatio;
    }
    
    /************************* Public write function **************************/
    function addSource(string calldata source) external pure returns (bool) {
        // Dummy function in order to keep compatibilities of `CarbonCreditNFT`
        return true;
    }
    
    function delSource(uint256 sourceId) external pure returns (bool) {
        // Dummy function in order to keep compatibilities of `CarbonCreditNFT`
        return true;
    }
    
    function addIssueBy(
        string calldata issueBy,
        uint16 ratio
    ) external pure returns (bool) {
        // Dummy function in order to keep compatibilities of `CarbonCreditNFT`
        return true;
    }
    
    function delIssueBy(uint256 issueById) external pure returns (bool) {
        // Dummy function in order to keep compatibilities of `CarbonCreditNFT`
        return true;
    }
    
    function addOrSetRatio(
        uint256 issueById,
        uint16 ratio
    ) external pure returns (bool) {   
        // Dummy function in order to keep compatibilities of `CarbonCreditNFT`     
        return true;
    }
    
    /************************* Public write function **************************/
    /**
     * @dev Mint the new CO2e Certificate NFT
     * 
     * This function is meant to be called by `ERC20TokenCenter`, otherwise
     * it will revert.
     */
    function mintToken(
        address receiver,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        require(
            msg.sender == address(erc20TokenCenter),
            "Caller is not allowed to invoke this function"
        );
        
        // Check whether `amount` is qualified for all the criterias
        require(
            amount >= minSwapAmount,
            "`amount` must be at least `minSwapAmount` Carbon Credit FTs"
        );
        require(
            (amount % uint256(certIssueByRatio)) == 0,
            "Conversion `amount` must be a multiple of `ratio`"
        );
        
        // Check whether `amount` will cause `weight` to be overflow
        uint256 pseudoWeight = amount / uint256(certIssueByRatio);
        require(
            pseudoWeight <= type(uint64).max,
            "Try to convert overwhelming amount of Carbon Credit FTs"
        );
        uint64 weight = uint64(pseudoWeight);
        
        // Transfer `ERC20TokenCenter` tokens to this contract
        TransferFromHelper.safeTransferFrom(
            address(erc20TokenCenter),
            address(erc20TokenCenter),
            address(this),
            amount
        );
        
        // Burn "Carbon Credit FT" ERC20 tokens
        erc20TokenCenter.burnToken(address(this), amount);
        
        // Mint a new ERC721 token "CO2e Certificate NFT"
        uint256 newTokenId = _mintToken(
            TokenData(
                bytes32(abi.encodePacked(uuidGenerator.generateUUID4())),
                uint192(block.timestamp), // Higher-order bits are cut off.
                weight
            ),
            receiver
        );
        
        return newTokenId;
    }
    
    // function burnToken(uint256 tokenId) external returns (bool) {
    // /**
    //  * @dev We don't implement this function, because it does not make
    //  * sense at all, where ones could use their CO2e Certificate tokens to 
    //  * get Carbon Credit tokens. If they want to do this, they just put
    //  * those NFTs into our `ERC721VaultFactory` for `fractionalization()`.
    //  */
    // }
    
    /**************************** Private function ****************************/
    function _constructTokenURI(
        uint256 tokenId
    ) private view returns (string memory) {
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return string(
            abi.encode(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encode(
                            '{"certId":"',
                            string(bytes.concat(tokenData.certId)),
                            '", "sourceId":"',
                            Strings.toString(certSourceId),
                            '", "issueById":"',
                            Strings.toString(certIssueById),
                            '", "weight":"',
                            Strings.toString(tokenData.weight),
                            '", "date":"',
                            string.concat(Strings.toString((block.timestamp>>192)), Strings.toString(tokenData.date)),
                            '"}'
                        )
                    )
                )
            )
        );
    }
    
    function _mintToken(
        TokenData memory newTokenData,
        address receiver
    ) private returns (uint256) {
        uint256 newTokenId;
        unchecked {
            newTokenId = (currTokenId++);
        }
        
        _safeMint(receiver, newTokenId);
        _setTokenURI(newTokenId, newTokenData);
        
        return newTokenId;
    }
    
    function _setTokenURI(
        uint256 tokenId,
        TokenData memory newTokenData
    ) private {
        require(ERC721._exists(tokenId), "Cannot set non-existent token");
        _tokenURIs[tokenId] = newTokenData;
        emit MetadataUpdate(tokenId);
    }
    
    /************************** Overriding function ***************************/
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _constructTokenURI(tokenId);
    }
}