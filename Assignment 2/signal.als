open util/ordering[State] as ord

// Names of you and your partner:
// FILL IN HERE

// the type of addresses
abstract sig Address {}

// some addresses are controlled by potential attackers
sig AttackerAddress extends Address {}

// one address belongs to the User who we model in this file
one sig UserAddress extends Address {}

// the four message types used in the protocol
abstract sig MessageType {}
one sig SDPOffer, SDPAnswer, SDPCandidates, Connect 
  extends MessageType {}

// a message has a type, plus a source (sender) and
// destination (receiver) addresses
sig Message {
  type  : MessageType,
  source: Address,
  dest  : Address,
}


// the seven recorded call states
// SignallingOffered, SignallingOngoing are used only by the caller
// SignallingStart, SignallingAnswered, and Answered are used by the 
// callee
// SignallingComplete is used by both caller and callee
abstract sig CallState {}
one sig SignallingStart, SignallingOffered, SignallingAnswered,
        SignallingOngoing,
        SignallingComplete, Answered 
  extends CallState {}


/* caller                                 callee
   ------                                 ------
                   ---- SDPOffer --->  
   SignallingOffered                          
                                          SignallingStart
                    <--- SDPAnswer ----
                                          SignallingAnswered
   SignallingOngoing
                  ---- SDPCandidates --->
   SignallingComplete
                                          SignallingComplete
                                                              ------ ringing >> 
                                                              <<--- user answers
                                          Answered
                  <---- Connect -------
                                          audio connected
   audio connected
                                          
*/
   
// the state of the system
sig State {
  ringing: lone Address, // whether the User is ringing and if so for whicih caller
  calls: Address -> lone CallState, // the recorded call state for each call currently in progress
  audio: lone Address,  // the participant that the User's audio is connected to
  last_answered: lone Address, // the last caller the User answered a call from
  last_called: lone Address,   // the last callee that the User called
  network: lone Message        // the network, records the most recent message sent 
}

// precondition for the User to send a message m in state s
pred user_send_pre[m : Message, s : State] {
  m.source in UserAddress and
  (
   (m.type in SDPOffer and m.dest = s.last_called and no s.calls[m.dest]) or
   (m.type in SDPAnswer and s.calls[m.dest] = SignallingStart) or
   (m.type in SDPCandidates and s.calls[m.dest] = SignallingOngoing) or
   (m.type in Connect and s.calls[m.dest] = Answered and 
     s.last_answered = m.dest)
  )
}

// precondition for the User to receive a message m in state s
pred user_recv_pre[m : Message, s : State] {
  m in s.network and
  m.dest in UserAddress and
  (
   (m.type in SDPOffer and no s.calls[m.source]) or
   (m.type in SDPAnswer and s.calls[m.source] = SignallingOffered) or
   (m.type in SDPCandidates and s.calls[m.source] = SignallingAnswered) or
   (m.type in Connect 
    and s.calls[m.source]=SignallingComplete)
  )
}

// postcondition for the user sending a message m.
// s is the state the message is sent in and s' is the state
// after sending the message
//
// No need to specify here that last_called and last_answered to not change
pred user_send_post[m : Message, s : State, s' : State] {
  s'.network = m and
  // FILL IN HERE
  (
    (m.type in SDPOffer and s'.calls = s.calls + (m.dest -> SignallingOffered) and s'.audio = s.audio and s'.ringing = s.ringing and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
    (m.type in SDPAnswer and s'.calls = s.calls ++ (m.dest -> SignallingAnswered) and s'.audio = s.audio and s'.ringing = s.ringing and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
    (m.type in SDPCandidates and s'.calls = s.calls ++ (m.dest -> SignallingComplete) and s'.audio = s.audio and s'.ringing = s.ringing and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
//Before fixing the vulnerability
 // (m.type in Connect and s'.audio = m.dest and s'.calls = s.calls and s'.ringing = s.ringing and s'.last_called = s.last_called and  no s'.last_answered)
//after fix
(m.type in Connect and s'.audio = s.last_called and s'.calls = s.calls and s'.ringing = s.ringing and s'.last_called = s.last_called and  no s'.last_answered)
  )
}

// postcondition for the user receiving a message m
// s is the state before the message was received; s'
// is hte state after the message was received
//
// No need to specify here that last_called and last_answered to not change
pred user_recv_post[m : Message, s : State, s' : State] {
  no s'.network and
  // FILL IN HERE
  (
    (m.type in SDPOffer and s'.calls = s.calls + (m.source -> SignallingStart) and s'.audio = s.audio and s'.ringing = s.ringing and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
    (m.type in SDPAnswer and s'.calls = s.calls ++ (m.source -> SignallingOngoing)and s'.audio = s.audio and s'.ringing = s.ringing and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
    (m.type in SDPCandidates and s'.calls = s.calls ++ (m.source -> SignallingComplete) and s'.ringing = m.source and s'.audio = s.audio and s'.last_called = s.last_called and s'.last_answered = s.last_answered) or
//Before fixing the vulnerability
  // (m.type in Connect and s'.audio = m.source and s'.calls = s.calls and no s'.last_called and s'.last_answered = s.last_answered)
//after fix
(m.type in Connect and s'.audio = s.last_answered and s'.calls = s.calls and s'.ringing = s.ringing and s'.last_called = s.last_called and no s'.last_answered)
  )
}

run user_send_pre for 4 but 8 State
run user_recv_pre for 4 but 8 State

run user_send_post for 4 but 8 State
run user_recv_post for 4 but 8 State

// the action of the attacker sending a message
// s is the state before the message is sent, s' is the state after
pred attacker_msg[s, s' : State] {
  some m : Message | m.source in AttackerAddress and
  s'.network = m and
  s'.calls = s.calls and
  s'.audio = s.audio and
  s'.ringing = s.ringing and
  s'.last_called = s.last_called and
  s'.last_answered = s.last_answered
}

// the action of the user either sending or receiving a message
pred user_msg[s, s' : State] {
  s'.last_answered = s.last_answered and
  s'.last_called = s.last_called and
  some m : Message |
    (user_send_pre[m,s] and user_send_post[m,s,s']) or
    (user_recv_pre[m,s] and user_recv_post[m,s,s'])
}

// the action of the user deciding to answer a ringing call
// doing so removes the "ringing" information from the state
// and changes the recorded call state to Answered but otherwise
// does not modify anything
pred user_answers[s, s' : State] {
  some caller : Address |
  s.calls[caller] in SignallingComplete and
  s.ringing = caller and 
  s'.audio = s.audio and
  no s'.ringing and
  s'.calls = s.calls ++ (caller -> Answered) and
  s'.last_answered = caller and
  s'.last_called = s.last_called and
  s'.network = s.network
}

// teh action of the user deciding to call another participant
// doing so simply updates the last_called state and also cancels
// any current "ringing" state
pred user_calls[s, s' : State] {
  some callee : Address | s'.last_called = callee and
  s'.network = s.network and
  s'.calls = s.calls and
  s'.last_answered = s.last_answered and
  s'.audio = s.audio and
  no s'.ringing   // calling somebody else stops any current ringing call
}

// a state transition is either the user sending or receiving a msg
// or answering a call, or choosing to call somebody, or the attacker
// sending a message on the network
pred state_transition[s, s' : State] {
  user_msg[s,s'] or user_answers[s,s'] or
  attacker_msg[s,s']  or user_calls[s,s']
}

pred show[s, s' : State] {
	some s:State, s':State | state_transition[s, s'] and
	first.network.type in SDPOffer and last.network.type in Connect and last.calls[last.last_called]=Answered // => some last.audio and no last.last_answered //and s'.calls[a] = SignallingComplete
}
//run show for 4
run show  for exactly 1 AttackerAddress, 4 Message, 1 Connect, 1 SDPOffer, 1 SDPCandidates, 1 SDPAnswer, 16 State, 1 SignallingStart, 1 SignallingOffered, 1 SignallingAnswered,
        1 SignallingOngoing, 1 SignallingComplete, 1 Answered 
// defines the initial state
// purposefully allow starting in a state where the User already
// wants to call somebody
pred init[s : State] {
    no s.audio and no s.ringing and
    no s.last_answered and
    no s.network and
    all dest : Address | no s.calls[dest]
}

fact {
  all s: ord/first | init[s]
}

fact {
  all s: State, s': ord/next[s] | state_transition[s,s']
}



// a  bad state is one in which the User's audio is connected
// to a participant but the User has not yet decided to call that
// participant or to answer a call from them
//assert no_bad_states {
 // FILL IN HERE
// all s: State | all s': ord/next[s] | 
//	(state_transition[s, s'] and s'.audio in Address) implies no s'.ringing
//}

assert no_bad_states {
 // FILL IN HERE
   all s: State | s.audio in Address and s.calls[s.audio]= SignallingComplete implies s.audio = s.last_called
//	no s'.ringing=>(s'.calls[s'.last_called]!=Answered and (s'.audio in AttackerAddress ) ) 
	//no s'.ringing=>(s'.calls[s'.last_called]!=Answered and (s'.audio in AttackerAddress ) ) 
	//s'.audio in AttAddress=>lone s'.ringing and s'.calls[s'.last_called]!=Answered
	//s'.last_called in AttackerAddress and s.last_called in UserAddress implies 
//	 no s'.ringing=>state_transition[s, s'] and s'.network.dest in AttackerAddress and 
//		s'.network.source in UserAddress 
	//s'.last_answered in AttackerAddress or s'.last_called in AttackerAddress =>
//	s'.calls[s'.last_called]!=Answered => s'.audio not in Address
//	s'.calls[s'.audio]!=Connected and no s'.ringing=>(s'.audio in UserAddress and (s.last_answered in AttackerAddress ))
//(s'.last_called in AttackerAddress) and (s'.calls[s'.audio]=Connected) and s'.audio in Address 

	//(state_transition[s, s'] and s'.audio in Address) implies no s'.ringing
}


// describe the vulnerability that this check identified
// The markers will reverse the "fix" to your model that you
// implemented and then run this "check" to make sure the vulnerability
// can be seen as described here.
// FILL IN HERE

// Choose a suitable bound for this check to show hwo the
// vulnerability does not arise in your fixed protocol
// Justify / explain your choice of your bound and
// specifically, what guarantees you think are provided by this check.
// FILL IN HERE
// See the assignment handout for more details here.
check no_bad_states for 6//  but 30 State // CHOOSE BOUND HERE
//run user_send_pre for 4 but 8 State
//run user_recv_pre for 4 but 8 State

//run user_send_post for 4 but 8 State
//run user_recv_post for 4 but 8 State

run{ first.network.type in SDPOffer and last.network.type in Connect and last.calls[last.last_called]=Answered } for 8 State, 1 AttackerAddress, 4 Message
//run {no last.last_answered and first.network.type=SDPOffer and last.calls[last.audio]=Answered} for 8 State, 1 AttackerAddress, 4 Message
run {
	some addr1: AttackerAddress | some s, s': State |
	(no s.last_answered and  s.calls[s.last_called]=Answered => s.audio = addr1) and
	(s'.last_answered = addr1 and s'.audio = addr1)
}
for 16 State ,1 AttackerAddress, 4 Message

run {
some addr1, addr2: AttackerAddress | addr1!=addr2 and some s1, s2:State
(no s1.last_answered and s1.audio = addr1) and
(s2.last_answered =addr2 and s2.audio =addr

}

// Alloy "run" commands and predicate definitions to
// showing successful execution of your (fixed) protocol
// FILL IN HERE
// These should include
// (1) The user successfully initiates a call (i.e. is the caller), 
// resulting in their audio being connected to the callee
// (2) The user makes a call and receives a call in the same 
// execution trace, so that in one state their audio is connected 
// to one participant and in another state it is connected to some
// other participant

// Describe how you fixed the model to remove the vulnerability
// FILL IN HERE
// Your description should have enough detail to allow somebody
// to "undo" (or "reverse") your fix so we can then see the vulnerability
// in your protocol as you describe it in comments above
