// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CallObject, UserObjective, AdditionalData} from "src/interfaces/ICallBreaker.sol";
import {CallBreakerTestHelper} from "test/utils/CallBreakerTestHelper.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {MockDaiWethPool} from "src/tests/Defi/MockDaiWethPool.sol";
import {MockERC20Token} from "src/utils/MockERC20Token.sol";
import {SignatureHelper} from "test/utils/SignatureHelper.sol";

contract FlashLiquidityProvider is Test {
    MockERC20Token public dai;
    MockERC20Token public weth;
    MockDaiWethPool public daiWethPool;
    CallBreaker public callBreaker;
    SignatureHelper public signatureHelper;

    address public owner = address(0x1);
    address public provider = vm.addr(0x2);

    uint256 public userPrivateKey = 0x1;
    address public user = vm.addr(userPrivateKey);

    uint256 public solverPrivateKey = 0x2;
    address public solver = vm.addr(solverPrivateKey);

    function setUp() external {
        callBreaker = new CallBreaker(owner);
        signatureHelper = new SignatureHelper(callBreaker);
        dai = new MockERC20Token("Dai", "DAI");
        weth = new MockERC20Token("Weth", "WETH");
        daiWethPool = new MockDaiWethPool(address(callBreaker), address(dai), address(weth));
        daiWethPool.mintInitialLiquidity();

        //mint tokens to the provider
        dai.mint(provider, 100 * 1e18);
        weth.mint(provider, 10 * 1e18);

        //mint dai to user to perform swap
        dai.mint(user, 10 * 1e18);

        // Give user some ETH
        vm.deal(user, 10 ether);
        vm.deal(solver, 10 ether);

        vm.startPrank(provider);
        dai.transfer(address(callBreaker), 100 * 1e18);
        weth.transfer(address(callBreaker), 10 * 1e18);
        vm.stopPrank();

        vm.startPrank(user);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker
        dai.transfer(address(callBreaker), 10 * 1e18);
        vm.stopPrank();

        vm.prank(solver);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker
    }

    function testFlashLiquiditySwap() external {
        // Prepare and push user objective
        CallObject[] memory userCallObjs = new CallObject[](2);
        userCallObjs[0] = CallBreakerTestHelper.buildCallObject(
            address(dai), abi.encodeWithSignature("approve(address,uint256)", address(daiWethPool), 10 * 1e18), ""
        );
        userCallObjs[1] = CallBreakerTestHelper.buildCallObject(
            address(daiWethPool), abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", 10, 2), ""
        );

        UserObjective memory userObjective = CallBreakerTestHelper.buildUserObjectiveWithAllParams(
            hex"01", 1, 0, block.chainid, 0, 0, user, userCallObjs
        );

        callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));

        // Create user objectives for executeAndVerify
        UserObjective[] memory userObjs = new UserObjective[](2);
        userObjs[0] = userObjective;

        // CallObjects of solver
        CallObject[] memory callObjs = new CallObject[](7);
        callObjs[0] = CallBreakerTestHelper.buildCallObject(
            address(dai), abi.encodeWithSignature("approve(address,uint256)", address(daiWethPool), 100 * 1e18), ""
        );
        callObjs[1] = CallBreakerTestHelper.buildCallObject(
            address(weth), abi.encodeWithSignature("approve(address,uint256)", address(daiWethPool), 10 * 1e18), ""
        );
        //callObject of provider to provide liquidity
        callObjs[2] = CallBreakerTestHelper.buildCallObject(
            address(daiWethPool),
            abi.encodeWithSignature(
                "provideLiquidityToDAIETHPool(address,uint256,uint256)", address(callBreaker), 100, 10
            ),
            ""
        );
        // to fulfill future call request in swapDAIForWETH function
        callObjs[3] = CallObject({
            salt: 0,
            amount: 0,
            gas: 10000000,
            addr: address(daiWethPool),
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", 2),
            returnvalue: "",
            skippable: false,
            verifiable: true,
            exposeReturn: true
        });
        // callObjects of provider to withdraw liquidity
        callObjs[4] = CallBreakerTestHelper.buildCallObject(
            address(daiWethPool),
            abi.encodeWithSignature(
                "withdrawLiquidityFromDAIETHPool(address,uint256,uint256)", address(callBreaker), 100, 10
            ),
            ""
        );
        // transfer the token back to provider
        callObjs[5] = CallBreakerTestHelper.buildCallObject(
            address(dai), abi.encodeWithSignature("transfer(address,uint256)", provider, 100 * 1e18), ""
        );
        callObjs[6] = CallBreakerTestHelper.buildCallObject(
            address(weth), abi.encodeWithSignature("transfer(address,uint256)", provider, 10 * 1e18), ""
        );

        userObjs[1] = CallBreakerTestHelper.buildUserObjective(0, solver, callObjs);

        // generate signature
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signatureHelper.generateSignature(userObjs[0], userPrivateKey);
        signatures[1] = signatureHelper.generateSignature(userObjs[1], solverPrivateKey);

        // setting order of execution
        uint256[] memory orderOfExecution = new uint256[](9);
        // provide liquidity callObjects
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 3;
        orderOfExecution[2] = 4;
        // future callObjects
        orderOfExecution[3] = 5;
        // user swp callObjects
        orderOfExecution[4] = 0;
        orderOfExecution[5] = 1;
        // withdraw liquidity callObjects
        orderOfExecution[6] = 6;
        // transfer tokens to provider
        orderOfExecution[7] = 7;
        orderOfExecution[8] = 8;

        // return value
        bytes[] memory returnValues = new bytes[](9);
        //provider provide liquidity return value
        returnValues[0] = abi.encode(true);
        returnValues[1] = abi.encode(true);
        returnValues[2] = "";
        // future Call return value
        returnValues[3] = "";
        // user swap return values
        returnValues[4] = abi.encode(true);
        returnValues[5] = "";
        // provider withdraw liquidity return value
        returnValues[6] = "";
        // transfer the token to provider
        returnValues[7] = abi.encode(true);
        returnValues[8] = abi.encode(true);

        // solver executing the executeAndVerify()
        vm.prank(solver);
        callBreaker.executeAndVerify(
            userObjs, signatures, returnValues, orderOfExecution, CallBreakerTestHelper.emptyMevTimeData()
        );

        assertEq(dai.balanceOf(address(daiWethPool)), 100010 * 1e18);
        assertLe(weth.balanceOf(address(daiWethPool)), 999998 * 1e18);
        assertEq(dai.balanceOf(user), 0);
        assertGe(weth.balanceOf(user), 0);
        assertEq(dai.balanceOf(address(callBreaker)), 0);
    }
}
