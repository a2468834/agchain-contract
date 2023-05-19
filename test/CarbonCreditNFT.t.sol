// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/nft/CarbonCreditNFT.sol";

contract TestCarbonCreditNFT is Test {
    CarbonCreditNFT token;
    
    address receiver = address(0x1234);
    
    function setUp() public {
        token = new CarbonCreditNFT(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG0"),
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG1")
        );
        token.addSource("Coelho Inc.");
        token.addSource("Smith Inc.");
        token.addSource("Frank Inc.");
        token.addIssueBy("Henry VCS", 1);
        token.addIssueBy("Jordan VCS", 22);
        token.addIssueBy("Gerald VCS", 333);
    }
    
    function testTokenMetadata() public {
        assertEq(token.name(), "CarbonCredit");
        assertEq(token.symbol(), "CC");
    }
    
    function testMintToken() public {
        uint256 token_id = 0;
        bool result;
        
        result = token.mintToken(
            CarbonCreditNFT.NewTokenData(
                "1st certificate",
                0,
                0,
                123456
            ),
            receiver
        );
        
        assertEq(result, true);
        assertEq(token.balanceOf(receiver), 1);
        assertEq(token.ownerOf(token_id), receiver);
        // emit log_string(token.tokenURI(token_id));
    }
    
    function testSourceAddAndDel() public {
        vm.expectRevert("Forbid empty `source`");
        token.addSource("");
        
        vm.expectRevert("The length of `source` <= 32 bytes");
        token.addSource("abcdefghijklmnopqrstuvwxyzABCDEFG");
        
        token.addSource("Patrick Inc.");
        token.getSourceList();
        
        token.delSource(2);
        token.getSourceList();
    }
    
    function testdIssueByAddAndDel() public {
        vm.expectRevert("Forbid empty `issueBy`");
        token.addIssueBy("", 0);
        
        vm.expectRevert("The length of `issueBy` <= 30 bytes");
        token.addIssueBy("abcdefghijklmnopqrstuvwxyzABCDE", 0);
        
        vm.expectRevert("Conversion `ratio` must be non-zero");
        token.addIssueBy("Pass VCS", 0);
        
        token.addIssueBy("Christina VCS", 4444);
        token.getIssueByList();
        
        token.delIssueBy(2);
        token.getIssueByList();
    }
    
    function testRatioGetAndSet() public {
        uint16 result;
        
        result = token.getRatio(0);
        assertEq(result, 1);
        
        token.addOrSetRatio(0, uint16(0xffff));
        result = token.getRatio(0);
        assertEq(result, 65535);
        
        vm.expectRevert("Cannot modify non-existent `issueBy`");
        token.addOrSetRatio(23, uint16(0xffff));
        
        token.delIssueBy(2);
        vm.expectRevert("Cannot modify non-existent `issueBy`");
        token.addOrSetRatio(2, uint16(0xffff));
    }
    
    function testGetTokenInfo() public {
        token.mintToken(
            CarbonCreditNFT.NewTokenData(
                "1st certificate",
                0,
                0,
                123456
            ),
            receiver
        );
        
        token.getTokenInfo(0);
    }
    
    function testGetTokenInfoLiterally() public {
        token.mintToken(
            CarbonCreditNFT.NewTokenData(
                "1st certificate",
                0,
                0,
                123456
            ),
            receiver
        );
        
        token.getTokenInfoLiterally(0);
    }
    
    function testOwnable() public {
        address rando = address(0xffff);
        vm.startPrank(rando);
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.addSource("Nichols Inc.");
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.delSource(2);
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.addIssueBy("Anna VCS", 55555);
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.delIssueBy(2);
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.addOrSetRatio(2, 55555);
        
        vm.expectRevert("Ownable: caller is not the owner");
        token.mintToken(
            CarbonCreditNFT.NewTokenData(
                "fake certificate",
                73,
                73,
                0xabcdef
            ),
            rando
        );
        
        vm.stopPrank();
    }
}

