# Sui Chat Protocol

A decentralized chat protocol built on the Sui blockchain.

## Overview

This project implements a chat protocol using Sui Move, allowing users to create chat rooms, send messages, and manage members in a decentralized manner. All chat data is stored on-chain, ensuring transparency and immutability.

## Modules

### Chatroom
The `chatroom` module provides core functionality for creating and managing chat rooms:
- Create chat rooms with custom names
- Send messages with content and timestamps
- Member management (join/leave chat rooms)
- Admin privileges for moderation
- Message deletion capabilities
- Event emission for all major actions

Key features:
- Owner controls room settings
- Admins can help moderate the room
- Members can send messages
- Messages are stored with timestamps
- Events are emitted for all major actions

### User
The `user` module handles user profiles:
- Register users with usernames
- Update usernames
- Store user profile information on-chain

## Getting Started

### Prerequisites
- [Sui CLI installed](https://docs.sui.io/guides/developer/getting-started/sui-install)

### Building
```bash
sui move build
```

### Testing
```bash
sui move test
```

## Key Features
- Decentralized chat rooms
- On-chain message storage
- Member and admin management
- Event-driven architecture
- User profile management

## Architecture
The protocol uses Sui's object model where:
- Chat rooms are objects owned by their creators
- Messages are stored in tables within chat room objects
- User profiles are separate objects linked to addresses
- All actions emit events for easy indexing and monitoring

## License

Apache-2.0
