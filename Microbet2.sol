pragma solidity ^0.4.25;


import './MicrobetLine2.sol';

contract Microbet2 {

    MicrobetLine2 microbetLine;
    address public Bettor;
    address public AnteUp;

    enum BetResult {
        Won,
        Lost
    } 
    BetResult public betResult;

    enum StateType {
        BetPlaced,
        PaymentRequested,
        PaymentSuccessfull,
        PaymentFailed,
        BetConfirmed,
        BetCancelled,
        BetLocked,
        BetResultRequested,
        BetResultProvided,
        BetWon,
        BetLost,
        LetItRide,
        CashedOut
    }
    StateType public State;

    uint public trackignId;
    uint public parentContractId = 0;
    uint public betId;
    uint public betAmount;
    uint public gameStartTime;
    string public paypalId;
    string public reason;

    bool public betWon;

    uint[] public childContractIds;


    mapping (uint => MicrobetLine2) public contractIdMapping;
    mapping (uint => StateType) public contractStateMapping;
    mapping (uint => uint) public contractStartGameTimeMapping;

    modifier canPerformedByBettor() {
        require(Bettor == msg.sender, 'Can only be performed by bettor');
        _;
    }

    modifier canOnlyPerformedByAnteUp() {
        require(AnteUp == msg.sender, 'Can only be performed by bettor');
        _;
    }

    constructor( address _anteUp, uint _betId, uint _betAmount, string _paypalId, uint _gameStartTime ) public {
        Bettor = msg.sender;
        AnteUp = _anteUp;
        trackignId = random();

        betId = _betId;
        betAmount = _betAmount;
        paypalId = _paypalId;
        gameStartTime = _gameStartTime;
        State = StateType.BetPlaced;
        contractStartGameTimeMapping[trackignId] = _gameStartTime;
        contractStateMapping[trackignId] = StateType.BetPlaced;
    }

    function requestAmount( uint _trackingId ) public canOnlyPerformedByAnteUp {

        if( _trackingId == trackignId ) {
            State = StateType.PaymentRequested;
        } else {
             contractIdMapping[_trackingId].requestAmount();
        }
        contractStateMapping[_trackingId] = StateType.PaymentRequested;
        
    }

    function receivePayment( bool _paymentSuccessFull, uint _trackingId) public canOnlyPerformedByAnteUp {

        if( _trackingId == trackignId) {
            if(_paymentSuccessFull) {
                State = StateType.PaymentSuccessfull;
                State = StateType.BetConfirmed;
                contractStateMapping[_trackingId] = StateType.BetConfirmed;
            } else {
                State = StateType.PaymentFailed;
                State = StateType.BetCancelled;
                contractStateMapping[_trackingId] = StateType.BetCancelled;
            }
        } else {
            contractIdMapping[_trackingId].receivePayment(_paymentSuccessFull);
            if(_paymentSuccessFull) {
                contractStateMapping[_trackingId] = StateType.BetConfirmed;
            } else {
                contractStateMapping[_trackingId] = StateType.BetCancelled;
            }
        }
        
        
    }

    function cancelBet( string _reason, uint _trackingId) public canPerformedByBettor {
        require(checkIfAnyChildBetIslocked() == false, 'Some Child bets are locked');
        require(contractStateMapping[_trackingId] != StateType.BetLocked, 'Bet is locked, so cannot be cancelled');
        require(contractStartGameTimeMapping[_trackingId] - block.timestamp >= 300,  'Bet cannot be cancelled, because game is about to start in 5 mins or less');
        if(_trackingId == trackignId) {
            reason = _reason;
            State = StateType.BetCancelled;
            endAllChildBet();
        } else {
            contractIdMapping[_trackingId].cancelBet(_reason);
        }
        contractStateMapping[_trackingId] = StateType.BetCancelled;
        
    }

    function lockBet(uint _trackingId) public canOnlyPerformedByAnteUp {
        if( _trackingId == trackignId ) {
            State = StateType.BetLocked;
        } else {
            contractIdMapping[_trackingId].lockBet();
        }
        contractStateMapping[_trackingId] = StateType.BetLocked;
        
    }

    function requestBetResult(uint _trackingId) public canPerformedByBettor {
        if( _trackingId == trackignId ) {
            State = StateType.BetResultRequested;
        } else {
            contractIdMapping[_trackingId].requestBetResult();
        }
        contractStateMapping[_trackingId] = StateType.BetResultRequested;
        
    }

    function provideBetResult( BetResult _betResult, uint _trackingId ) public  canOnlyPerformedByAnteUp{

        if( _trackingId == trackignId ) {
            betResult = _betResult;
            State = StateType.BetResultProvided;
            if( _betResult ==  BetResult.Won ) {
                State = StateType.BetWon;
                betWon = true;
                contractStateMapping[_trackingId] = StateType.BetWon;
            } else {
                State = StateType.BetLost;
                betWon = false;
                contractStateMapping[_trackingId] = StateType.BetLost;
            }
        } else {
            contractIdMapping[_trackingId].provideBetResult(betWon);
            if( _betResult ==  BetResult.Won) {
                contractStateMapping[_trackingId] = StateType.BetWon;
            } else {
                contractStateMapping[_trackingId] = StateType.BetLost;
            }
        }
        
       
    }

    function createNewBet(uint _betId, uint _betAmount, string _paypalId, uint _gameStartTime, uint _trackingId ) public canPerformedByBettor {
        require(State != StateType.CashedOut, 'Parent Bet is already cashed out');
        require(contractStateMapping[_trackingId] != StateType.CashedOut, 'Bet is already cashed out');
        if( _trackingId == trackignId ) {
            State = StateType.LetItRide;
        } else {
            contractIdMapping[_trackingId].createNewBet();
        }
        
        uint childTrackingId = random();

        microbetLine = new MicrobetLine2(AnteUp, _betId, _betAmount, _paypalId, _gameStartTime, this, msg.sender, _trackingId, childTrackingId);
        contractIdMapping[childTrackingId] = microbetLine;
        contractStartGameTimeMapping[childTrackingId] = _gameStartTime;
        contractStateMapping[_trackingId] = StateType.LetItRide;
        childContractIds.push(childTrackingId);
    }

    function cashOut( uint _trackingId ) public canPerformedByBettor {
        require(checkIfAnyChildBetIslocked() == false, 'Some Child bets are locked');
        require(contractStateMapping[_trackingId] == StateType.BetWon, 'You cannot cash out');
        if( _trackingId == trackignId ) {
            State = StateType.CashedOut;
            endAllChildBet();
        } else {
            contractIdMapping[_trackingId].cashOut();
        }
        contractStateMapping[_trackingId] = StateType.CashedOut;
        
    }

      //generate a random number to generate contract ids for child contracts
    function random() private view returns (uint) {
        return (uint256(keccak256(block.timestamp, block.difficulty))%251);
    }

    function endAllChildBet() public {
        for(uint i = 0; i < childContractIds.length; i++ ) {
            contractIdMapping[childContractIds[i]].endBet();
        }
    }
    function GetchildContractIds() public constant  returns (uint []) {
        return childContractIds;
    }

    function checkIfAnyChildBetIslocked() public returns (bool) {
        for(uint i = 0; i < childContractIds.length; i++ ) {
            if(contractStateMapping[childContractIds[i]] == StateType.BetLocked) {
                return true;
            }
        }

        return false;
    }
}