#[test_only]
module sui_chat::user_tests;

use sui::test_scenario::{Self, next_tx};
use sui_chat::user::{Self, UserProfile};

const ADMIN: address = @0x0;
const USER1: address = @0x1;

#[test]
fun test_register_and_update_user() {
    let mut scenario = test_scenario::begin(ADMIN);

    // Register User1
    next_tx(&mut scenario, USER1);
    {
        user::register_user(b"user1_name".to_string(), scenario.ctx());
    };

    // USER1 should have the UserProfile object, take it from USER1
    next_tx(&mut scenario, USER1);
    {
        let mut profile = scenario.take_from_sender<UserProfile>();
        let (user_addr, username, _) = user::get_user_info(&profile);

        assert!(user_addr == USER1, 0);
        assert!(username == b"user1_name".to_string(), 1);

        // Update username
        next_tx(&mut scenario, USER1);
        user::update_username(&mut profile, b"user1_new_name".to_string(), scenario.ctx());

        let (_, new_username, _) = user::get_user_info(&profile);
        assert!(new_username == b"user1_new_name".to_string(), 2);

        scenario.return_to_sender(profile);
    };

    scenario.end();
}
