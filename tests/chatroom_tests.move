#[test_only]
module sui_chat::chatroom_tests;

use sui::test_scenario::{Self, next_tx};
use sui_chat::chatroom::{Self, ChatRoom};

const ADMIN: address = @0x0;
const USER1: address = @0x1;
const USER2: address = @0x2;
const USER3: address = @0x3;

#[test]
fun test_create_room_send_and_get_messages() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Sui Hackathon 2025".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();
        let (name, owner, _, msg_count, member_count) = chatroom::get_chatroom_info(&room);

        assert!(name == b"Sui Hackathon 2025".to_string(), 0);
        assert!(owner == USER1, 1);
        assert!(msg_count == 0, 2);
        assert!(member_count == 1, 3);

        // USER1 sends a message
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Hello Sui!".to_string(), scenario.ctx());

        // USER2 joins the room
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // USER2 sends a message
        next_tx(&mut scenario, USER2);
        chatroom::send_message(&mut room, b"Hello from User2!".to_string(), scenario.ctx());

        // Verify messages
        let (_, _, _, new_msg_count, _) = chatroom::get_chatroom_info(&room);
        assert!(new_msg_count == 2, 4);

        let messages = chatroom::get_messages(&room, 0, 2);

        let msg1 = vector::borrow(&messages, 0);
        assert!(chatroom::get_message_sender(msg1) == USER1, 5);
        assert!(chatroom::get_message_content(msg1) == b"Hello Sui!".to_string(), 6);

        let msg2 = vector::borrow(&messages, 1);
        assert!(chatroom::get_message_sender(msg2) == USER2, 7);
        assert!(chatroom::get_message_content(msg2) == b"Hello from User2!".to_string(), 8);

        // Transfer the room back to USER1 to consume it properly
        chatroom::transfer_chatroom(room, USER1);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_MESSAGE_TOO_LONG)]
fun test_send_message_too_long() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // Create a message that is too long (1025 bytes)
        let mut long_message = vector::empty<u8>();
        let mut i = 0;
        while (i < 1025) {
            vector::push_back(&mut long_message, 65u8); // 'A' character
            i = i + 1;
        };
        let long_message = std::string::utf8(long_message);

        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, long_message, scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_NOT_MEMBER)]
fun test_join_and_leave_chatroom() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Test Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();
        let (_, _, _, _, init_member_count) = chatroom::get_chatroom_info(&room);
        assert!(init_member_count == 1, 0); // Only owner initially

        // USER2 joins the room
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // Verify member count increased
        let (_, _, _, _, new_member_count) = chatroom::get_chatroom_info(&room);
        assert!(new_member_count == 2, 1);

        // USER3 joins the room
        next_tx(&mut scenario, USER3);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // Verify member count increased again
        let (_, _, _, _, new_member_count2) = chatroom::get_chatroom_info(&room);
        assert!(new_member_count2 == 3, 2);

        // USER2 tries to leave the room
        next_tx(&mut scenario, USER2);
        chatroom::leave_chatroom(&mut room, scenario.ctx());

        // Verify member count decreased
        let (_, _, _, _, new_member_count3) = chatroom::get_chatroom_info(&room);
        assert!(new_member_count3 == 2, 3);

        // USER2 tries to leave again (should fail because not a member)
        next_tx(&mut scenario, USER2);
        chatroom::leave_chatroom(&mut room, scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
fun test_member_and_admin_management() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Admin Test Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER2 joins the room
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // USER3 joins the room
        next_tx(&mut scenario, USER3);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // Check initial state
        assert!(chatroom::is_member(&room, USER1), 0); // Owner is member
        assert!(chatroom::is_member(&room, USER2), 1);
        assert!(chatroom::is_member(&room, USER3), 2);
        assert!(chatroom::is_admin(&room, USER1), 3); // Owner is admin
        assert!(!chatroom::is_admin(&room, USER2), 4);
        assert!(!chatroom::is_admin(&room, USER3), 5);

        // USER1 (owner) adds USER2 as admin
        next_tx(&mut scenario, USER1);
        chatroom::add_admin(&mut room, USER2, scenario.ctx());

        // Check admin status
        assert!(chatroom::is_admin(&room, USER1), 6);
        assert!(chatroom::is_admin(&room, USER2), 7);
        assert!(!chatroom::is_admin(&room, USER3), 8);

        // USER2 (now admin) adds USER3 as admin
        next_tx(&mut scenario, USER2);
        chatroom::add_admin(&mut room, USER3, scenario.ctx());

        // Check admin status
        assert!(chatroom::is_admin(&room, USER1), 9);
        assert!(chatroom::is_admin(&room, USER2), 10);
        assert!(chatroom::is_admin(&room, USER3), 11);

        // USER1 (owner) removes USER3 as admin
        next_tx(&mut scenario, USER1);
        chatroom::remove_admin(&mut room, USER3, scenario.ctx());

        // Check admin status
        assert!(chatroom::is_admin(&room, USER1), 12);
        assert!(chatroom::is_admin(&room, USER2), 13);
        assert!(!chatroom::is_admin(&room, USER3), 14);

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_NOT_MEMBER)]
fun test_send_message_not_member() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Restricted Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER2 tries to send a message without joining (should fail)
        next_tx(&mut scenario, USER2);
        chatroom::send_message(&mut room, b"Unauthorized message".to_string(), scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_ALREADY_MEMBER)]
fun test_join_already_member() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Full Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER2 joins the room
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // USER2 tries to join again (should fail)
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
fun test_get_messages_pagination() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Paginated Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // Send multiple messages
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Message 1".to_string(), scenario.ctx());
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Message 2".to_string(), scenario.ctx());
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Message 3".to_string(), scenario.ctx());
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Message 4".to_string(), scenario.ctx());
        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"Message 5".to_string(), scenario.ctx());

        // Verify total message count
        let (_, _, _, msg_count, _) = chatroom::get_chatroom_info(&room);
        assert!(msg_count == 5, 0);

        // Get first 3 messages
        let first_three = chatroom::get_messages(&room, 0, 3);
        assert!(vector::length(&first_three) == 3, 1);

        // Get last 2 messages
        let last_two = chatroom::get_messages(&room, 3, 2);
        assert!(vector::length(&last_two) == 2, 2);

        // Get messages from middle
        let middle = chatroom::get_messages(&room, 1, 3);
        assert!(vector::length(&middle) == 3, 3);

        // Verify content of specific messages
        let msg0 = vector::borrow(&first_three, 0);
        assert!(chatroom::get_message_content(msg0) == b"Message 1".to_string(), 4);

        let msg4 = vector::borrow(&last_two, 1);
        assert!(chatroom::get_message_content(msg4) == b"Message 5".to_string(), 5);

        // Transfer the room back to USER1 to consume it properly
        chatroom::transfer_chatroom(room, USER1);
    };

    scenario.end();
}

#[test]
fun test_room_info_and_stats() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Info Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // Check initial info
        let (name, owner, created_at, msg_count, member_count) = chatroom::get_chatroom_info(&room);
        assert!(name == b"Info Room".to_string(), 0);
        assert!(owner == USER1, 1);
        assert!(msg_count == 0, 2);
        assert!(member_count == 1, 3);

        // Get stats
        let (stats_members, stats_msgs, stats_created) = chatroom::get_room_stats(&room);
        assert!(stats_members == 1, 4);
        assert!(stats_msgs == 0, 5);
        assert!(stats_created == created_at, 6);

        // Add members and messages
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        next_tx(&mut scenario, USER3);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        next_tx(&mut scenario, USER1);
        chatroom::send_message(&mut room, b"First message".to_string(), scenario.ctx());

        next_tx(&mut scenario, USER2);
        chatroom::send_message(&mut room, b"Second message".to_string(), scenario.ctx());

        // Check updated info
        let (_, _, _, new_msg_count, new_member_count) = chatroom::get_chatroom_info(&room);
        assert!(new_msg_count == 2, 7);
        assert!(new_member_count == 3, 8);

        // Check updated stats
        let (new_stats_members, new_stats_msgs, _) = chatroom::get_room_stats(&room);
        assert!(new_stats_members == 3, 9);
        assert!(new_stats_msgs == 2, 10);

        // Transfer the room back to USER1 to consume it properly
        chatroom::transfer_chatroom(room, USER1);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_NOT_OWNER)]
fun test_add_admin_by_non_admin() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Admin Test Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER2 joins as member first
        next_tx(&mut scenario, USER2);
        chatroom::join_chatroom(&mut room, scenario.ctx());

        // USER2 (member but not admin) tries to add an admin (should fail)
        next_tx(&mut scenario, USER2);
        chatroom::add_admin(&mut room, USER3, scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_NOT_OWNER)]
fun test_owner_only_operations() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Owner Only Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER2 tries to add an admin (should fail - not owner or admin)
        next_tx(&mut scenario, USER2);
        {
            // Join first to become a member
            chatroom::join_chatroom(&mut room, scenario.ctx());
        };

        // USER2 (member but not admin) tries to add an admin (should fail)
        next_tx(&mut scenario, USER2);
        {
            chatroom::add_admin(&mut room, USER3, scenario.ctx());
        };

        scenario.return_to_sender(room);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = sui_chat::chatroom::E_NOT_OWNER)]
fun test_owner_cannot_leave_room() {
    let mut scenario = test_scenario::begin(ADMIN);

    // USER1 creates a chatroom
    next_tx(&mut scenario, USER1);
    {
        chatroom::create_chatroom(b"Owner Protected Room".to_string(), scenario.ctx());
    };

    // USER1 should have the ChatRoom object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut room = scenario.take_from_sender<ChatRoom>();

        // USER1 (owner) tries to leave the room (should fail)
        next_tx(&mut scenario, USER1);
        chatroom::leave_chatroom(&mut room, scenario.ctx());

        scenario.return_to_sender(room);
    };

    scenario.end();
}
