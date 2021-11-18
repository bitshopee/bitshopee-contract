pragma solidity ^0.8.9;
//SPDX-License-Identifier: MIT

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BitShopeePayTask is Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct Task{
        uint id;
        address userAddress;
        address agentAddress;
        address payToken;
        uint payAmount;
        uint payDeadline;
        uint confirmDeadline;
        /*
            101 waiting for agent to pay
            102 waiting for user to confirm
            103 waiting for agent's consent to cancel
            104 waiting for platform to judge

            200 finished
            201 finished after timeout
            202 finished after judgement

            400 cancelled by user
            401 cancelled by agent
        */
        uint status;
    }

    event TaskStatusChanged(
        uint indexed taskId,
        uint indexed oldStatus,
        uint indexed newStatus,
        Task taskInfo
    );


    uint public payTimeout=30 minutes;
    uint public confirmTimeout=1 days;
    address public adminAddress;
    uint public feeRate;//10 refers to 1%
    address public feeAddress;

    mapping(uint=>Task) taskMapping;
    mapping(address=>uint) userOngoingTaskId;

    modifier onlyAdmin() {
        require(adminAddress == msg.sender, "BS:caller is not the admin");
        _;
    }


    constructor(address _adminAddress,uint _feeRate,address _feeAddress){
        adminAddress=_adminAddress;
        feeRate=_feeRate;
        feeAddress=_feeAddress;
    }

    function createTask(Task calldata task) external whenNotPaused{
        require(task.id>0&&taskMapping[task.id].id==0,"BS:task id exists");
        require(userOngoingTaskId[msg.sender]==0,"BS:ongoing task exists");

        taskMapping[task.id].id=task.id;
        taskMapping[task.id].userAddress=msg.sender;
        taskMapping[task.id].agentAddress=task.agentAddress;
        taskMapping[task.id].payToken=task.payToken;
        taskMapping[task.id].payAmount=task.payAmount;
        taskMapping[task.id].payDeadline=block.timestamp+payTimeout;
        
        changeTaskStatus(task.id, 101);

    }

    function paidByAgent(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==101 || taskMapping[taskId].status==103,"BS:task status error");
        require(taskMapping[taskId].agentAddress==msg.sender,"BS:no permission");
        require(block.timestamp<=taskMapping[taskId].payDeadline,"BS:pay deadline passed");

        changeTaskStatus(taskId, 102);
        taskMapping[taskId].confirmDeadline=block.timestamp+confirmTimeout;
    }

    function confirmByUser(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==102,"BS:task status error");
        require(taskMapping[taskId].userAddress==msg.sender,"BS:no permission");

        changeTaskStatus(taskId, 200);
    }

    function cancelByUser(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==101 || taskMapping[taskId].status==103,"BS:task status error");
        require(taskMapping[taskId].userAddress==msg.sender,"BS:no permission");

        if(block.timestamp <= taskMapping[taskId].payDeadline){
            if(taskMapping[taskId].status!=103)
                changeTaskStatus(taskId, 103);
        }
        else{//already timeout
            changeTaskStatus(taskId, 400);
        }
    }

    function cancelByAgent(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==101,"BS:task status error");
        require(taskMapping[taskId].agentAddress==msg.sender,"BS:no permission");

        changeTaskStatus(taskId, 401);
    }

    function agreeCancelByAgent(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==103,"BS:task status error");
        require(taskMapping[taskId].agentAddress==msg.sender,"BS:no permission");

        changeTaskStatus(taskId, 400);
    }

    function checkTimeoutByAgent(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==102,"BS:task status error");
        require(taskMapping[taskId].agentAddress==msg.sender,"BS:no permission");
        require(block.timestamp>taskMapping[taskId].confirmDeadline,"BS:still in progress");

        changeTaskStatus(taskId, 201);
    }

    function appealByUser(uint taskId) external whenNotPaused{
        require(taskMapping[taskId].status==102,"BS:task status error");
        require(taskMapping[taskId].userAddress==msg.sender,"BS:no permission");
        require(block.timestamp<=taskMapping[taskId].confirmDeadline,"BS:confirm deadline passed");

        changeTaskStatus(taskId, 104);

    }

    function confirmByAdmin(uint taskId) external whenNotPaused onlyAdmin{
        require(taskMapping[taskId].status==104,"BS:task status error");

        changeTaskStatus(taskId, 202);
    }

    function cancelByAdmin(uint taskId) external whenNotPaused onlyAdmin{
        require(taskMapping[taskId].status==104,"BS:task status error");

        changeTaskStatus(taskId, 402);
    }


    function changeTaskStatus(uint taskId,uint newStatus) private {
        require(taskMapping[taskId].id>0,"BS:task doesn't exist");
        require(taskMapping[taskId].status!=newStatus,"BS:status no change");

        uint oldStatus=taskMapping[taskId].status;
        taskMapping[taskId].status=newStatus;

        if(newStatus==101){//create task
            userOngoingTaskId[msg.sender]=taskId;
            IERC20(taskMapping[taskId].payToken).safeTransferFrom(taskMapping[taskId].userAddress,address(this),taskMapping[taskId].payAmount);
        }

        if(oldStatus<200 && newStatus>=200){//finished
            userOngoingTaskId[msg.sender]=0;
        
            if(newStatus>=200 && newStatus<300){//successful, transfer money to agent
                uint fee=taskMapping[taskId].payAmount*feeRate/1000;
                if(fee>0)
                    IERC20(taskMapping[taskId].payToken).safeTransfer(feeAddress,fee);
                IERC20(taskMapping[taskId].payToken).safeTransfer(taskMapping[taskId].agentAddress,taskMapping[taskId].payAmount-fee);
            }
            else if(newStatus>=400){//error, return money back
                IERC20(taskMapping[taskId].payToken).safeTransfer(taskMapping[taskId].userAddress,taskMapping[taskId].payAmount);
            }
        }

        emit TaskStatusChanged(taskId, oldStatus, newStatus, taskMapping[taskId]);

    }

    function queryTask(uint taskId) public view returns(Task memory){
        return taskMapping[taskId];
    }

    function getOngoingTaskId(address userAddress) public view returns(uint){
        return userOngoingTaskId[userAddress];
    }

    function setPayTimeout(uint _timeout) external onlyOwner {
        payTimeout=_timeout;
    }

    function setConfirmTimeout(uint _timeout) external onlyOwner {
        confirmTimeout=_timeout;
    }

    function setAdmin(address _admin) external onlyOwner {
        adminAddress=_admin;
    }

     function setFeeRate(uint _feeRate) external onlyOwner {
        require(_feeRate<=1000,"BS:too big");
        feeRate=_feeRate;
    }

     function setFeeAddress(address _feeAddress) external onlyOwner {
       feeAddress=_feeAddress;
    }
}