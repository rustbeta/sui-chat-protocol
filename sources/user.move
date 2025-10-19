module sui_chat::user;

use std::string::String;
use sui::event;

public struct UserProfile has key {
    id: UID,
    user: address,
    username: String,
    created_at: u64,
}

public struct UserRegistered has copy, drop {
    user: address,
    username: String,
    timestamp: u64,
}

public entry fun register_user(username: String, ctx: &mut TxContext) {
    let sender = ctx.sender();

    let user_profile = UserProfile {
        id: object::new(ctx),
        user: sender,
        username,
        created_at: ctx.epoch(),
    };

    transfer::transfer(user_profile, sender);

    event::emit(UserRegistered {
        user: sender,
        username,
        timestamp: ctx.epoch(),
    });
}

public entry fun update_username(
    profile: &mut UserProfile,
    new_username: String,
    ctx: &mut TxContext,
) {
    let sender = ctx.sender();
    assert!(profile.user == sender, 2); // E_NOT_AUTHORIZED

    profile.username = new_username;
}

public fun get_user_info(profile: &UserProfile): (address, String, u64) {
    (profile.user, profile.username, profile.created_at)
}
