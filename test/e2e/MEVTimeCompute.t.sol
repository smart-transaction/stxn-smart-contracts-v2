// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CallObject, UserObjective, AdditionalData, ICallBreaker, MevTimeData} from "src/interfaces/ICallBreaker.sol";
import {CallBreaker} from "src/CallBreaker.sol";
import {MEVTimeCompute} from "src/tests/MEVTimeCompute.sol";
import {CallBreakerTestHelper} from "../utils/CallBreakerTestHelper.sol";
import {SignatureHelper} from "../utils/SignatureHelper.sol";

contract MEVTimeComputeTest is Test {
    CallBreaker public callBreaker;
    MEVTimeCompute public mevTimeCompute;
    SignatureHelper public signatureHelper;

    address public owner = address(0x1);

    uint256 public solverPrivateKey = 0x2;
    address public solver = vm.addr(solverPrivateKey);

    uint256 public userPrivateKey = 0x1;
    address public user = vm.addr(userPrivateKey);

    uint256 public validatorPrivateKey = 0x3;
    address public validator = vm.addr(validatorPrivateKey);

    function setUp() public {
        callBreaker = new CallBreaker(owner);
        signatureHelper = new SignatureHelper(callBreaker);
        mevTimeCompute = new MEVTimeCompute(address(callBreaker), 10); // assuming the divisor is 10
        mevTimeCompute.setInitValue(93);
        vm.deal(user, 10 ether);
        vm.deal(solver, 10 ether); // Give solver some ETH for execution
        vm.prank(user);
        callBreaker.deposit{value: 5 ether}();
        vm.prank(solver);
        callBreaker.deposit{value: 1 ether}();

        vm.prank(owner);
        callBreaker.setValidatorAddress(hex"01", validator);
    }

    function test_MEVTimeCompute() public {
        // Prepare and push user objective
        CallObject[] memory callObjects = new CallObject[](1);
        callObjects[0] = CallObject({
            salt: 0,
            amount: 0,
            gas: 100_000,
            addr: address(mevTimeCompute),
            callvalue: abi.encodeWithSignature("solve()"),
            returnvalue: "", // Empty return value, will use returnValues array
            skippable: false,
            verifiable: true,
            exposeReturn: true
        });

        UserObjective memory userObjective =
            CallBreakerTestHelper.buildUserObjectiveWithAllParams(hex"01", 1, 0, block.chainid, 0, 0, user, callObjects);

        callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));

        // Create user objectives for executeAndVerify
        UserObjective[] memory userObjs = new UserObjective[](2);
        userObjs[0] = userObjective;

        // check is solution worked and updated the value, also to fulfill future call request in solve function
        CallObject memory futureCall = CallObject({
            salt: 0,
            amount: 0,
            gas: 1000000,
            addr: address(mevTimeCompute),
            callvalue: abi.encodeWithSignature("verifySolution()"),
            returnvalue: "",
            skippable: false,
            verifiable: true,
            exposeReturn: true
        });

        CallObject[] memory futureCallObjects = new CallObject[](1);
        futureCallObjects[0] = futureCall;
        userObjs[1] = CallBreakerTestHelper.buildUserObjective(0, solver, futureCallObjects);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signatureHelper.generateSignature(userObjs[0], userPrivateKey);
        signatures[1] = signatureHelper.generateSignature(userObjs[1], solverPrivateKey);

        bytes[] memory returnValues = new bytes[](2);
        returnValues[0] = abi.encode(0);
        returnValues[1] = "";

        // solver action to solve the problem with MEV Time value
        uint256[] memory orderOfExecution = new uint256[](2);
        orderOfExecution[0] = 0;
        orderOfExecution[1] = 1;

        // Pass the solution in AdditionalData to executeAndVerify
        uint256 solution = mevTimeCompute.divisor() - (mevTimeCompute.initValue() % mevTimeCompute.divisor());
        AdditionalData[] memory mevTimeData = new AdditionalData[](1);
        mevTimeData[0] = AdditionalData({key: keccak256(abi.encodePacked("solvedValue")), value: abi.encode(solution)});

        bytes memory validatorSignature = signatureHelper.generateValidatorSignature(mevTimeData, validatorPrivateKey);

        vm.prank(solver);
        callBreaker.executeAndVerify(
            userObjs, signatures, returnValues, orderOfExecution, MevTimeData(validatorSignature, mevTimeData)
        );
    }
}
