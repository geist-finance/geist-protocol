// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "../interfaces/IMultiFeeDistribution.sol";
import "../dependencies/openzeppelin/contracts/IERC20.sol";
import "../dependencies/openzeppelin/contracts/SafeERC20.sol";
import "../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../dependencies/openzeppelin/contracts/Ownable.sol";

// based on the Sushi MasterChef
// https://github.com/sushiswap/sushiswap/blob/master/contracts/MasterChef.sol
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    // Info of each pool.
    struct PoolInfo {
        uint256 totalSupply;
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardTime; // Last second that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
    }
    // Info about token emissions for a given time period.
    struct EmissionPoint {
        uint128 startTimeOffset;
        uint128 rewardsPerSecond;
    }

    address public poolConfigurator;

    IMultiFeeDistribution public rewardMinter;
    uint256 public rewardsPerSecond;

    // Info of each pool.
    address[] public registeredTokens;
    mapping(address => PoolInfo) public poolInfo;

    // Data about the future reward rates. emissionSchedule stored in reverse chronological order,
    // whenever the number of blocks since the start block exceeds the next block offset a new
    // reward rate is applied.
    EmissionPoint[] public emissionSchedule;
    // token => user => Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when reward mining starts.
    uint256 public startTime;

    event Deposit(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    event Withdraw(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    event EmergencyWithdraw(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    constructor(
        uint128[] memory _startTimeOffset,
        uint128[] memory _rewardsPerSecond,
        address _poolConfigurator,
        IMultiFeeDistribution _rewardMinter
    )
        Ownable()
    {
        poolConfigurator = _poolConfigurator;
        rewardMinter = _rewardMinter;
        uint256 length = _startTimeOffset.length;
        for (uint256 i = length - 1; i + 1 != 0; i--) {
            emissionSchedule.push(
                EmissionPoint({
                    startTimeOffset: _startTimeOffset[i],
                    rewardsPerSecond: _rewardsPerSecond[i]
                })
            );
        }
    }

    // Start the party
    function start() public onlyOwner {
        require(startTime == 0);
        startTime = block.timestamp;
    }

    // Add a new lp to the pool. Can only be called by the poolConfigurator.
    function addPool(address _token, uint256 _allocPoint) external {
        require(msg.sender == poolConfigurator);
        require(poolInfo[_token].lastRewardTime == 0);
        _updateEmissions();
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        registeredTokens.push(_token);
        poolInfo[_token] = PoolInfo({
            totalSupply: 0,
            allocPoint: _allocPoint,
            lastRewardTime: block.timestamp,
            accRewardPerShare: 0
        });
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function batchUpdateAllocPoint(
        address[] calldata _tokens,
        uint256[] calldata _allocPoints
    ) public onlyOwner {
        require(_tokens.length == _allocPoints.length);
        _massUpdatePools();
        uint256 _totalAllocPoint = totalAllocPoint;
        for (uint256 i = 0; i < _tokens.length; i++) {
            PoolInfo storage pool = poolInfo[_tokens[i]];
            require(pool.lastRewardTime > 0);
            _totalAllocPoint = _totalAllocPoint.sub(pool.allocPoint).add(_allocPoints[i]);
            pool.allocPoint = _allocPoints[i];
        }
        totalAllocPoint = _totalAllocPoint;
    }

    function poolLength() external view returns (uint256) {
        return registeredTokens.length;
    }

    // View function to see pending SUSHIs on frontend.
    function claimableReward(address _token, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = userInfo[_token][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.totalSupply;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 duration = block.timestamp.sub(pool.lastRewardTime);
            uint256 reward = duration.mul(rewardsPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }


    function _updateEmissions() internal {
        uint256 length = emissionSchedule.length;
        if (startTime > 0 && length > 0) {
            EmissionPoint memory e = emissionSchedule[length-1];
            if (block.timestamp.sub(startTime) > e.startTimeOffset) {
                 _massUpdatePools();
                rewardsPerSecond = uint256(e.rewardsPerSecond);
                emissionSchedule.pop();
            }
        }
    }

    // Update reward variables for all pools
    function _massUpdatePools() internal {
        uint256 totalAP = totalAllocPoint;
        uint256 length = registeredTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            _updatePool(registeredTokens[i], totalAP);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(address _token, uint256 _totalAllocPoint) internal {
        PoolInfo storage pool = poolInfo[_token];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.totalSupply;
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 duration = block.timestamp.sub(pool.lastRewardTime);
        uint256 reward = duration.mul(rewardsPerSecond).mul(pool.allocPoint).div(_totalAllocPoint);
        pool.accRewardPerShare = pool.accRewardPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens into the contract. Also triggers a claim.
    function deposit(address _token, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = userInfo[_token][msg.sender];
        _updateEmissions();
        _updatePool(_token, totalAllocPoint);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accRewardPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            rewardMinter.mint(msg.sender, pending, true);
        }
        IERC20(_token).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Deposit(_token, msg.sender, _amount);
    }

    // Withdraw LP tokens. Also triggers a claim.
    function withdraw(address _token, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = userInfo[_token][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        _updateEmissions();
        _updatePool(_token, totalAllocPoint);
        uint256 pending =
            user.amount.mul(pool.accRewardPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            rewardMinter.mint(msg.sender, pending, true);
        }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        IERC20(_token).safeTransfer(address(msg.sender), _amount);
        emit Withdraw(_token, msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(address _token) external {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = userInfo[_token][msg.sender];
        IERC20(_token).safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(_token, msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Claim pending rewards for one or more pools.
    // Rewards are not received directly, they are minted by the rewardMinter.
    function claim(address[] calldata _tokens, address _receiver) external {
        _updateEmissions();
        uint256 pending;
        uint256 _totalAllocPoint = totalAllocPoint;
        for (uint i = 0; i < _tokens.length; i++) {
            PoolInfo storage pool = poolInfo[_tokens[i]];
            require(pool.lastRewardTime > 0);
            _updatePool(_tokens[i], _totalAllocPoint);
            UserInfo storage user = userInfo[_tokens[i]][msg.sender];
            pending = pending.add(user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt));
            user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        }
        if (pending > 0) {
            rewardMinter.mint(_receiver, pending, true);
        }
    }

}
