// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Simple Auction with advanced rules.
/// @author Gabriel Romero.
/// @notice This contract enables users to bid in an auction, supports dynamic extension of the end time,
/// allows partial and full refunds, and handles commission logic upon finalization.
contract Auction {
    /// @notice Structure to represent a bid and its bidder.
    struct Biders {
        uint256 amount;
        address bidder;
    }

    string public prize;
    address private owner;
    uint256 private startTime;
    uint256 private endTime;
    uint256 private extraTimeConstant = 10 minutes;
    uint256 private commissionPercentage = 2;

    /// @notice Stores the current highest bid and bidder.
    Biders public highestBid;
    /// @notice Tracks the full history of valid bids during the auction.
    Biders[] public bidHistory;

    /// @notice Records all bid amounts made by each user.
    mapping(address => uint256[]) public userBids;

    /// @notice Keeps track of the total ETH deposited by each user.
    mapping(address => uint256) public totalDeposits;

    /// @notice Emitted when a new valid bid is placed.
    event NewBid(address indexed bidder, uint256 amount);

    /// @notice Emitted when the auction is finalized.
    /// @param winner Address of the highest bidder.
    /// @param finalAmount The amount of the winning bid.
    /// @param prize Description.
    event AuctionEnded(address winner, uint256 finalAmount, string prize);

    /// @notice Initializes the auction with default duration (1 day).
    constructor() {
        prize = "Faberge egg from the Imperial Russian collection";
        owner = msg.sender;
        startTime = block.timestamp;
        endTime = startTime + 10 minutes;
    }

    /// @notice Ensures the auction is still active.
    modifier isActive() {
        require(block.timestamp < endTime, "Auction has ended");
        _;
    }

    /// @notice Restricts certain functions to only the contract owner.
    modifier isOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    /// @notice Places a bid on the auction. The bid must be greater than zero and exceed the current highest bid by at least 5%.
    /// @dev Extends the auction time by 10 minutes if a valid bid is placed with less than 10 minutes remaining.
    ///      The contract owner is not allowed to participate in the auction.
    /// @custom:requirements The auction must be active and the sender must not be the owner.
    /// @custom:events Emits a NewBid event upon a valid bid.

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

    /// @notice Returns the current highest bidder and amount.
    /// @return The address of the highest bidder and the amount bid.
    function viewWinner() external view returns (address, uint256) {
        return (highestBid.bidder, highestBid.amount);
    }

    /// @notice Returns the entire bid history.
    /// @return An array of all valid bids made.
    function viewBids() external view returns (Biders[] memory) {
        return bidHistory;
    }

    /// @notice Allows users to withdraw excess funds over their last valid bid while auction is active.
    function partialRefund() external isActive {
        uint256 total = totalDeposits[msg.sender];
        uint256[] memory myBids = userBids[msg.sender];

        require(myBids.length > 1, "No excess if you only made one bid");

        uint256 last = myBids[myBids.length - 1];
        uint256 excess = total - last;

        require(excess > 0, "No excess to withdraw");

        totalDeposits[msg.sender] = last;
        payable(msg.sender).transfer(excess);
    }

    /// @notice Finalizes the auction by distributing funds: the winner receives the prize minus commission,
    /// and other participants are refunded their deposits minus the same commission.
    /// @dev A 2% commission is deducted from every participant's total deposit, including the winner.
    /// @notice Ends the auction, collects funds from the winner, and refunds others with a 2% fee.
    function endAuction() external isOwner {
        require(block.timestamp >= endTime, "Auction is still active");

        uint256 winnerAmount = highestBid.amount;

        // Owner recibe el valor de la oferta ganadora.
        payable(owner).transfer(winnerAmount);

        // Devuelve el valor a los perdedores menos el 2% comision.
        for (uint256 i = 0; i < bidHistory.length; i++) {
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
        }

        emit AuctionEnded(highestBid.bidder, highestBid.amount, prize);
    }
}
