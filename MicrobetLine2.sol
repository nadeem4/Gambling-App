pragma solidity ^0.4.25;

contract MicrobetLine2 {
    address public Bettor;
    address public AnteUp;

    address public headerContractAddress;

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
    uint public parentContractId;
    uint public betId;
    uint public betAmount;
    uint public gameStartTime;
    string public paypalId;
    string public reason;

    modifier onlyCallableFromHeader() {
        require(headerContractAddress == msg.sender);
        _;
    }

    constructor( address _anteUp, uint _betId, uint _betAmount, string _paypalId, uint _gameStartTime, address _headerContractAddress, address _bettor, uint _parentTrackingId, uint _trackingId ) public {
        AnteUp = _anteUp;
        Bettor = _bettor;
        betId = _betId;
        betAmount = _betAmount;
        paypalId = _paypalId;
        gameStartTime = _gameStartTime;
        parentContractId = _parentTrackingId;
        headerContractAddress = _headerContractAddress;
        trackignId = _trackingId;
        State = StateType.BetPlaced;
    }

    function requestAmount() public  onlyCallableFromHeader{
        State = StateType.PaymentRequested;
    }

    function receivePayment( bool _paymentSuccessFull) public onlyCallableFromHeader {
        if(_paymentSuccessFull) {
            State = StateType.PaymentSuccessfull;
            State = StateType.BetConfirmed;
        } else {
            State = StateType.PaymentFailed;
            State = StateType.BetCancelled;
        }
    }

    function cancelBet( string _reason) public onlyCallableFromHeader{
        reason = _reason;
        State = StateType.BetCancelled;
    }

    function lockBet() public onlyCallableFromHeader {
        State = StateType.BetLocked;
    }

    function requestBetResult() public  onlyCallableFromHeader {
        State = StateType.BetResultRequested;
    }

    function provideBetResult( bool _betWon ) public onlyCallableFromHeader {
        State = StateType.BetResultProvided;
        State = StateType.BetResultProvided;
        if( _betWon) {
            betResult = BetResult.Won;
            State = StateType.BetWon;
        } else {
            betResult = BetResult.Lost;
            State = StateType.BetLost;
        }
    }

    function createNewBet(  ) public onlyCallableFromHeader {
        State = StateType.LetItRide;
    }

    function cashOut() public onlyCallableFromHeader {
        State = StateType.CashedOut;
    }

    function endBet() public{
        if( State == StateType.BetWon){
             State = StateType.CashedOut;
        } else if ( State == StateType.BetLost ) {
            State = StateType.BetLost;
        } else {
            State = StateType.BetCancelled;
        }

    }
}