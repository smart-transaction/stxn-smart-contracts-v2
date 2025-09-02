// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CallObject, UserObjective, AdditionalData, ICallBreaker, MevTimeData} from "src/interfaces/ICallBreaker.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {IBlockTime, BlockTime} from "src/tests/BlockTime.sol";
import {BlockTimeScheduler} from "src/tests/BlockTimeScheduler.sol";
import {TimeToken} from "src/tests/TimeToken.sol";
import {CallBreakerTestHelper} from "test/utils/CallBreakerTestHelper.sol";
import {SignatureHelper} from "test/utils/SignatureHelper.sol";

contract BlockTimeSchedulerTest is Test {
    TimeToken public timeToken;
    CallBreaker public callBreaker;
    SignatureHelper public signatureHelper;
    BlockTime public blockTime;
    BlockTimeScheduler public blockTimeScheduler;

    string constant timeTokenName = "Time Token";
    string constant timeTokenSymbol = "TIME";

    address public owner = address(0x1);
    address public deployer = address(0x2);
    address public pusher = address(0x3);
    address public filler = address(0x4);

    uint256 public userPrivateKey = 0x1;
    address public user = vm.addr(userPrivateKey);

    uint256 public solverPrivateKey = 0x2;
    address public solver = vm.addr(solverPrivateKey);

    uint256 public validatorPrivateKey = 0x3;
    address public validator = vm.addr(validatorPrivateKey);

    function setUp() public {
        callBreaker = new CallBreaker(owner);
        signatureHelper = new SignatureHelper(callBreaker);
        blockTime = new BlockTime(deployer);
        blockTimeScheduler = new BlockTimeScheduler(address(callBreaker), address(blockTime), deployer, solver);

        vm.startPrank(deployer);
        blockTime.grantRole(blockTime.SCHEDULER_ROLE(), address(blockTimeScheduler));
        vm.stopPrank();

        vm.deal(solver, 10 ether);

        vm.prank(solver);
        callBreaker.deposit{value: 5 ether}();

        vm.prank(owner);
        callBreaker.setValidatorAddress(hex"01", validator);
    }

    function testBlockTimeScheduler() public {
        // Prepare and push user objective
        CallObject[] memory userCallObjs = new CallObject[](1);

        userCallObjs[0] = CallBreakerTestHelper.buildCallObject(
            address(blockTimeScheduler), abi.encodeWithSignature("updateTime()"), ""
        );

        UserObjective memory userObjective = CallBreakerTestHelper.buildUserObjectiveWithAllParams(
            hex"01", 1, 0, block.chainid, 0, 0, user, userCallObjs
        );

        callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));

        // Create user objectives for executeAndVerify
        UserObjective[] memory userObjs = new UserObjective[](2);
        userObjs[0] = userObjective;

        //Prepare and push solver objective
        UserObjective memory futureUserObjective = CallBreakerTestHelper.buildUserObjectiveWithAllParams(
            hex"01", 1, 0, block.chainid, 0, 0, solver, userCallObjs
        );

        CallObject[] memory futureCallObj = new CallObject[](1);
        futureCallObj[0] = CallObject({
            salt: 0,
            amount: 0,
            gas: 1000000,
            addr: address(callBreaker),
            callvalue: abi.encodeWithSignature(
                "pushUserObjective((bytes,uint256,uint256,uint256,uint256,uint256,address,(uint256,uint256,uint256,address,bytes,bytes,bool,bool,bool)[]),(bytes32,bytes)[])",
                futureUserObjective,
                new AdditionalData[](0)
            ),
            returnvalue: "",
            skippable: false,
            verifiable: false,
            exposeReturn: false
        });

        userObjs[1] = CallBreakerTestHelper.buildUserObjective(0, solver, futureCallObj);

        // generate signature
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signatureHelper.generateSignature(userObjs[0], userPrivateKey);
        signatures[1] = signatureHelper.generateSignature(userObjs[1], solverPrivateKey);

        // setting order of execution
        uint256[] memory orderOfExecution = new uint256[](2);
        orderOfExecution[0] = 0;
        orderOfExecution[1] = 1;

        // return value
        bytes[] memory returnValues = new bytes[](2);
        returnValues[0] = "";
        returnValues[1] = "";

        // Additional Data
        (bytes memory chroniclesData, bytes memory meanTimeData, bytes memory receiversData, bytes memory amountsData) =
            _getUpdateTimeData(filler, pusher);
        AdditionalData[] memory mevTimeData = new AdditionalData[](4);
        mevTimeData[0] = AdditionalData({key: keccak256(abi.encodePacked("Chronicles")), value: chroniclesData});
        mevTimeData[1] = AdditionalData({key: keccak256(abi.encodePacked("CurrentMeanTime")), value: meanTimeData});
        mevTimeData[2] = AdditionalData({key: keccak256(abi.encodePacked("Receivers")), value: receiversData});
        mevTimeData[3] = AdditionalData({key: keccak256(abi.encodePacked("Amounts")), value: amountsData});

        bytes memory validatorSignature = signatureHelper.generateValidatorSignature(mevTimeData, validatorPrivateKey);

        // solver executing the executeAndVerify()
        vm.prank(solver);
        callBreaker.executeAndVerify(
            userObjs, signatures, returnValues, orderOfExecution, MevTimeData(validatorSignature, mevTimeData)
        );

        assertEq(TimeToken(blockTime.timeToken()).balanceOf(filler), 1e18);
    }

    function _getUpdateTimeData(address receiver, address _pusher)
        private
        view
        returns (
            bytes memory chroniclesData,
            bytes memory meanTimeData,
            bytes memory receiversData,
            bytes memory amountsData
        )
    {
        IBlockTime.Chronicle[] memory chronicles = new IBlockTime.Chronicle[](1);
        chronicles[0] = IBlockTime.Chronicle(100, _pusher, bytes(""));
        address[] memory receivers = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        receivers[0] = receiver;
        amounts[0] = 1e18;
        chroniclesData = abi.encode(chronicles);
        meanTimeData = abi.encode(block.timestamp);
        receiversData = abi.encode(receivers);
        amountsData = abi.encode(amounts);
    }
}
