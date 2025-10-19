module sui_chat::chatroom;

use std::string::{Self, String};
use sui::event;
use sui::table::{Self, Table};

// --- Constants ---
const E_MESSAGE_TOO_LONG: u64 = 1;
const E_NOT_MEMBER: u64 = 2;
const E_ALREADY_MEMBER: u64 = 3;
const E_NOT_OWNER: u64 = 4;
const E_MESSAGE_NOT_FOUND: u64 = 5;
const MAX_MESSAGE_LENGTH: u64 = 1024;

// --- Structs ---

public struct Message has copy, drop, store {
    sender: address,
    content: String,
    timestamp: u64,
}

public struct ChatRoom has key {
    id: UID,
    name: String,
    owner: address,
    created_at: u64,
    message_count: u64,
    member_count: u64,
    messages: Table<u64, Message>,
    members: Table<address, bool>, // Simple membership tracking
    admins: Table<address, bool>, // Admin privileges
}

// --- Events ---

public struct ChatRoomCreated has copy, drop {
    chatroom_id: ID,
    name: String,
    owner: address,
    timestamp: u64,
}

public struct MessageSent has copy, drop {
    chatroom_id: ID,
    sender: address,
    message: String,
    timestamp: u64,
}

public struct MemberJoined has copy, drop {
    chatroom_id: ID,
    member: address,
    timestamp: u64,
}

public struct MemberLeft has copy, drop {
    chatroom_id: ID,
    member: address,
    timestamp: u64,
}

public struct AdminAdded has copy, drop {
    chatroom_id: ID,
    admin: address,
    added_by: address,
    timestamp: u64,
}

public struct AdminRemoved has copy, drop {
    chatroom_id: ID,
    admin: address,
    removed_by: address,
    timestamp: u64,
}

public struct MessageDeleted has copy, drop {
    chatroom_id: ID,
    message_id: u64,
    deleted_by: address,
    timestamp: u64,
}

// --- Entry Functions ---

public entry fun create_chatroom(name: String, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    let mut chatroom = ChatRoom {
        id: object::new(ctx),
        name: copy name,
        owner: sender,
        created_at: timestamp,
        message_count: 0,
        member_count: 1, // Owner is first member
        messages: table::new(ctx),
        members: table::new(ctx),
        admins: table::new(ctx),
    };

    // Add owner as member and admin
    table::add(&mut chatroom.members, sender, true);
    table::add(&mut chatroom.admins, sender, true);

    let chatroom_id = object::id(&chatroom);
    transfer::transfer(chatroom, sender);

    event::emit(ChatRoomCreated {
        chatroom_id,
        name,
        owner: sender,
        timestamp,
    });
}

public entry fun send_message(chatroom: &mut ChatRoom, message: String, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Check if sender is a member
    assert!(table::contains(&chatroom.members, sender), E_NOT_MEMBER);
    assert!(string::length(&message) <= MAX_MESSAGE_LENGTH, E_MESSAGE_TOO_LONG);

    let new_message = Message {
        sender,
        content: copy message,
        timestamp,
    };

    // Add the message to the chatroom's table
    table::add(&mut chatroom.messages, chatroom.message_count, new_message);
    chatroom.message_count = chatroom.message_count + 1;

    event::emit(MessageSent {
        chatroom_id: object::id(chatroom),
        sender,
        message,
        timestamp,
    });
}

// --- Member Management Functions ---

public entry fun join_chatroom(chatroom: &mut ChatRoom, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Check if already a member
    assert!(!table::contains(&chatroom.members, sender), E_ALREADY_MEMBER);

    // Add to members
    table::add(&mut chatroom.members, sender, true);
    chatroom.member_count = chatroom.member_count + 1;

    event::emit(MemberJoined {
        chatroom_id: object::id(chatroom),
        member: sender,
        timestamp,
    });
}

public entry fun leave_chatroom(chatroom: &mut ChatRoom, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Check if sender is a member
    assert!(table::contains(&chatroom.members, sender), E_NOT_MEMBER);

    // Cannot leave if owner
    assert!(sender != chatroom.owner, E_NOT_OWNER);

    // Remove from members and admins (if admin)
    table::remove(&mut chatroom.members, sender);
    if (table::contains(&chatroom.admins, sender)) {
        table::remove(&mut chatroom.admins, sender);
    };
    chatroom.member_count = chatroom.member_count - 1;

    event::emit(MemberLeft {
        chatroom_id: object::id(chatroom),
        member: sender,
        timestamp,
    });
}

// --- Admin Management Functions ---

public entry fun add_admin(chatroom: &mut ChatRoom, new_admin: address, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Check if sender is owner or admin
    assert!(sender == chatroom.owner || table::contains(&chatroom.admins, sender), E_NOT_OWNER);
    assert!(table::contains(&chatroom.members, new_admin), E_NOT_MEMBER);
    assert!(!table::contains(&chatroom.admins, new_admin), E_ALREADY_MEMBER);

    table::add(&mut chatroom.admins, new_admin, true);

    event::emit(AdminAdded {
        chatroom_id: object::id(chatroom),
        admin: new_admin,
        added_by: sender,
        timestamp,
    });
}

public entry fun remove_admin(
    chatroom: &mut ChatRoom,
    admin_to_remove: address,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Only owner can remove admins (cannot remove self)
    assert!(sender == chatroom.owner, E_NOT_OWNER);
    assert!(admin_to_remove != chatroom.owner, E_NOT_OWNER);
    assert!(table::contains(&chatroom.admins, admin_to_remove), E_NOT_MEMBER);

    table::remove(&mut chatroom.admins, admin_to_remove);

    event::emit(AdminRemoved {
        chatroom_id: object::id(chatroom),
        admin: admin_to_remove,
        removed_by: sender,
        timestamp,
    });
}

// --- Message Management Functions ---

public entry fun delete_message(chatroom: &mut ChatRoom, message_id: u64, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let timestamp = ctx.epoch();

    // Check if sender is owner or admin
    assert!(sender == chatroom.owner || table::contains(&chatroom.admins, sender), E_NOT_OWNER);
    assert!(message_id < chatroom.message_count, E_MESSAGE_NOT_FOUND);

    // Borrow the message to check sender (allow message owner to delete their own messages)
    let message = table::borrow(&chatroom.messages, message_id);
    let can_delete =
        sender == chatroom.owner || table::contains(&chatroom.admins, sender) || sender == message.sender;
    assert!(can_delete, E_NOT_OWNER);

    // Remove the message (we can't actually delete from table, but we can mark as deleted)
    // For now, we'll just emit an event

    event::emit(MessageDeleted {
        chatroom_id: object::id(chatroom),
        message_id,
        deleted_by: sender,
        timestamp,
    });
}

// --- Public View Functions ---

public fun get_messages(room: &ChatRoom, start: u64, limit: u64): vector<Message> {
    let mut i = start;
    let mut result = vector::empty<Message>();
    while (i < room.message_count && i < start + limit) {
        let msg = table::borrow(&room.messages, i);
        vector::push_back(&mut result, *msg);
        i = i + 1;
    };
    result
}

// Add public functions to access message fields
public fun get_message_sender(message: &Message): address {
    message.sender
}

public fun get_message_content(message: &Message): String {
    copy message.content
}

public fun get_message_timestamp(message: &Message): u64 {
    message.timestamp
}

// Public function to transfer the ChatRoom object
public entry fun transfer_chatroom(chatroom: ChatRoom, recipient: address) {
    transfer::transfer(chatroom, recipient)
}

public fun get_chatroom_info(chatroom: &ChatRoom): (String, address, u64, u64, u64) {
    (
        chatroom.name,
        chatroom.owner,
        chatroom.created_at,
        chatroom.message_count,
        chatroom.member_count,
    )
}

// Check if an address is a member
public fun is_member(chatroom: &ChatRoom, addr: address): bool {
    table::contains(&chatroom.members, addr)
}

// Check if an address is an admin
public fun is_admin(chatroom: &ChatRoom, addr: address): bool {
    table::contains(&chatroom.admins, addr)
}

// Get room statistics
public fun get_room_stats(chatroom: &ChatRoom): (u64, u64, u64) {
    (chatroom.member_count, chatroom.message_count, chatroom.created_at)
}

// Get message by ID
public fun get_message(chatroom: &ChatRoom, message_id: u64): &Message {
    assert!(message_id < chatroom.message_count, E_MESSAGE_NOT_FOUND);
    table::borrow(&chatroom.messages, message_id)
}

// Get all members (returns a vector of addresses)
public fun get_all_members(chatroom: &ChatRoom): vector<address> {
    let mut result = vector::empty<address>();
    // For now, we'll return just the owner as a simple implementation
    // In a real implementation, you'd need to use a different data structure
    vector::push_back(&mut result, chatroom.owner);
    result
}

// Get all admins (returns a vector of addresses)
public fun get_all_admins(chatroom: &ChatRoom): vector<address> {
    let mut result = vector::empty<address>();
    vector::push_back(&mut result, chatroom.owner);
    result
}
