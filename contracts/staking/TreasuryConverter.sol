pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/IERC20.sol";

interface CryptoSwap {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface StableSwap {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

contract TreasuryConverter {

    IERC20 constant gDAI = IERC20(0x07E6332dD090D287d3489245038daF987955DCFB);
    IERC20 constant gUSDC = IERC20(0xe578C856933D8e1082740bf7661e379Aa2A30b26);
    IERC20 constant gUSDT = IERC20(0x940F41F0ec9ba1A34CF001cc03347ac092F5F6B5);
    IERC20 constant gWBTC = IERC20(0x38aCa5484B8603373Acc6961Ecd57a6a594510A3);

    IERC20 constant WBTC = IERC20(0x321162Cd933E2Be498Cd2267a90534A804051b11);
    IERC20 constant USDT = IERC20(0x049d68029688eAbF473097a2fC38ef61633A3C7A);

    ILendingPool constant lendingPool = ILendingPool(0x9FAD24f572045c7869117160A571B2e50b10d068);
    StableSwap constant gPool = StableSwap(0x0fa949783947Bf6c1b171DB13AEACBB488845B3f);
    CryptoSwap constant triCrypto = CryptoSwap(0x3a1659Ddcf2339Be3aeA159cA010979FB49155FF);
    address constant feeDistributor = 0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8;

    uint256 public lastSwapTimestamp;

    constructor() {
        gUSDT.approve(address(gPool), uint(-1));
        gUSDC.approve(address(gPool), uint(-1));
        WBTC.approve(address(triCrypto), uint(-1));
        USDT.approve(address(lendingPool), uint(-1));
    }

    function swapAndTransfer() public {
        require(block.timestamp > lastSwapTimestamp + 86400 * 3, "Can only call every 3 days");
        uint balance = gWBTC.balanceOf(address(this));
        if (balance > 0) {
            lendingPool.withdraw(address(WBTC), balance, address(this));
            balance = triCrypto.exchange(1, 0, balance, 0);
            lendingPool.deposit(address(USDT), balance, address(this), 0);
        }
        balance = gUSDT.balanceOf(address(this));
        if (balance > 0) {
            gPool.exchange(2, 0, balance, 0);
        }
        balance = gUSDC.balanceOf(address(this));
        if (balance > 0) {
            gPool.exchange(1, 0, balance, 0);
        }
        balance = gDAI.balanceOf(address(this));
        if (balance > 0) {
            gDAI.transfer(feeDistributor, balance);
            lastSwapTimestamp = block.timestamp;
        }
    }

}
