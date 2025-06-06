// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Auction
/// @author Gabriel Romero
/// @notice This contract enables users to participate in a competitive auction,
/// including bid history tracking, time extension near the deadline, partial refunds,
/// and commission handling upon finalization.
/// @dev Prevents the owner from bidding, adds time if bid is close to deadline,
/// and charges a 2% commission on refunds.
contract Auction {
    /// @notice Structure to represent a bid and its bidder.
    struct Biders {
        uint256 amount;
        address bidder;
    }
    /// @notice Description of the auction prize
    string public prize;
    /// @notice Address of the contract owner (auction creator).
    address private owner;
    /// @notice Timestamp when the auction started.
    uint256 private startTime;
    /// @notice Timestamp when the auction ends.
    uint256 public endTime;
    /// @notice Amount of time to extend if bid placed within the last 10 minutes.
    uint256 private extraTimeConstant = 10 minutes;
    /// @notice Percentage of commission (default is 2%) deducted from refunds.
    uint256 public commissionPercentage = 2;

    /// @notice History of all valid bids placed during the auction.
    Biders public highestBid;
    /// @notice Tracks the full history of valid bids during the auction.
    Biders[] public bidHistory;

    /// @notice Mapping from bidder address to list of all their bids.
    mapping(address => uint256[]) public userBids;

    /// @notice Mapping from address to total ETH deposited (accumulated bids).
    mapping(address => uint256) public totalDeposits;

    /// @notice Emitted when a valid bid is placed.
    /// @param bidder The address of the user who placed the bid.
    /// @param amount The amount of the bid.
    event NewBid(address indexed bidder, uint256 amount);

    /// @notice Emitted when the auction is finalized.
    /// @param winner Address of the highest bidder.
    /// @param finalAmount The amount of the winning bid.
    /// @param prize The description of the prize.
    event AuctionEnded(address winner, uint256 finalAmount, string prize);

    /// @notice Initializes the auction contract and sets the prize details.
    /// @dev Sets the contract deployer as the owner, initializes the start time to current block timestamp,
    /// and sets the auction end time to one day after deployment.
    /// The prize is hardcoded as "Faberge egg from the Imperial Russian collection".
    constructor() {
        prize = "Faberge egg from the Imperial Russian collection";
        owner = msg.sender;
        startTime = block.timestamp;
        endTime = startTime + 5 minutes;
    }

    /// @notice Ensures the auction is currently active.
    /// @dev Requires that current time is less than the end time.
    modifier isActive() {
        require(block.timestamp < endTime, "Auction has ended");
        _;
    }

    /// @notice Restricts certain functions to only the contract owner.
    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    /// @notice Places a new bid in the auction.
    /// @dev Extends the auction deadline by 10 minutes if bid is placed with less than 10 minutes remaining.
    /// @custom:requirements Bid amount must be greater than zero and at least 5% higher than the current highest bid.
    /// Owner is not allowed to bid.
    /// @custom:effects Updates the highest bid, records bid history, and updates user deposits.
    /// @custom:events Emits NewBid when a valid bid is placed.
    function bid() external payable isActive {
        // La oferta tiene que ser mayor que 0
        require(msg.value > 0, "Bid amount must be greater than zero");
        //Garantiza que la oferta sea mayor en un 5%
        require(
            msg.value > (highestBid.amount * 105) / 100,
            "Bid must exceed current highest by at least 5%"
        );
        // Impide que el ownet participe en la subasta
        require(msg.sender != owner, "Owner cannot participate in the auction");

        // Guarda historial y total depositado.
        userBids[msg.sender].push(msg.value);
        totalDeposits[msg.sender] += msg.value;

        // Actualiza la mejor oferta.
        highestBid = Biders(msg.value, msg.sender);
        bidHistory.push(highestBid);

        // Extiende tiempo si quedan menos de 10 minutos.
        if (endTime - block.timestamp < extraTimeConstant) {
            endTime += extraTimeConstant;
        }

        emit NewBid(msg.sender, msg.value);
    }

    /// @notice Returns the current highest bidder and their bid amount.
    /// @return bidder Address of the leading bidder.
    /// @return amount Value of the leading bid.
    function viewWinner() external view returns (address, uint256) {
        return (highestBid.bidder, highestBid.amount);
    }

    /// @notice Returns the full history of all bids placed during the auction.
    /// @return Array of Biders structs representing all valid bids.
    function viewBids() external view returns (Biders[] memory) {
        return bidHistory;
    }

    /// @notice Allows a bidder to withdraw excess funds from previous bids, leaving only their last bid.
    /// @dev Only applicable if the user has made multiple bids and has unused balance.
    /// @custom:requirements Auction must be active. User must have more than one bid.
    /// @custom:effects Refunds the difference between total deposits and the last bid.
    function partialRefund() external isActive {
        // Obtiene el total depositado por el usuario.
        uint256 total = totalDeposits[msg.sender];

        // Recupera el historial de ofertas del usuario.
        uint256[] memory myBids = userBids[msg.sender];

        // Si el usuario solo ofertó una vez, no hay exceso para retirar.
        require(myBids.length > 1, "No excess if you only made one bid");

        // Obtiene el valor de la última oferta realizada.
        uint256 last = myBids[myBids.length - 1];

        // Calcula el exceso como la diferencia entre el total depositado y la última oferta.
        uint256 excess = total - last;

        // Verifica que efectivamente haya exceso a devolver.
        require(excess > 0, "No excess to withdraw");

        // Actualiza el total de depósitos para reflejar solo la última oferta.
        totalDeposits[msg.sender] = last;

        // Devuelve el exceso de fondos al usuario.
        payable(msg.sender).transfer(excess);
    }

    /// @notice Finalizes the auction and distributes funds.
    /// @dev The owner receives the full amount of the winning bid. All other participants receive a refund minus a 2% commission.
    /// @custom:requirements Can only be called by the owner and only after the auction ends.
    /// @custom:effects Sends commission to the owner and refunds participants.
    /// @custom:events Emits AuctionEnded with the winner and final bid details.
    function endAuction() external isOwner {
        require(block.timestamp >= endTime, "Auction is still active");

        uint256 winnerAmount = highestBid.amount;

        // Owner recibe el valor de la oferta ganadora.
        payable(owner).transfer(winnerAmount);

        // Devuelve el valor a los perdedores menos el 2% comision.
        uint256 len = bidHistory.length;
        for (uint256 i = 0; i < len;) {
         
            address participant = bidHistory[i].bidder;

            if (participant != highestBid.bidder) {
                uint256 amount = totalDeposits[participant];

                if (amount > 0) {
                    uint256 commission = (amount * commissionPercentage) / 100;
                    uint256 refund = amount - commission;

                    totalDeposits[participant] = 0;

                    // Envia al Owner el 2% de todas las ofertas.
                    payable(owner).transfer(commission);
                    // devueve las ofertas.
                    payable(participant).transfer(refund);
                }
            }
               unchecked{i++;}
        }

        emit AuctionEnded(highestBid.bidder, highestBid.amount, prize);
    }
}
