# 🚗 Tokenised Ride Sharing System

A decentralized ride-sharing platform built on the Stacks blockchain using Clarity smart contracts. This system enables drivers and riders to interact directly without intermediaries, using fungible tokens for payments and featuring a reputation system.

## 🌟 Features

- **🔐 User Registration**: Separate registration for drivers and riders
- **🪙 Tokenized Payments**: Custom fungible tokens for seamless transactions
- **🚕 Ride Management**: Complete ride lifecycle from request to completion
- **⭐ Reputation System**: 5-star rating system for both drivers and riders
- **📊 Statistics Tracking**: Track earnings, total rides, and ratings
- **🔄 Driver Status Control**: Toggle availability on/off

## 🏗️ Contract Architecture

### Data Structures

#### Maps
- **`drivers`**: Stores driver information (name, vehicle, rating, earnings, status)
- **`riders`**: Stores rider information (name, rating, total rides, token balance)
- **`rides`**: Stores ride details (pickup, destination, fare, status, timestamps)

#### Fungible Token
- **`ride-token`**: Custom token used for all platform transactions

### Key Functions

#### 👤 User Management
- `register-driver`: Register as a driver with name and vehicle info
- `register-rider`: Register as a rider with name
- `toggle-driver-status`: Toggle driver availability

#### 🚗 Ride Operations
- `request-ride`: Create a new ride request
- `accept-ride`: Driver accepts a ride request
- `start-ride`: Mark ride as in progress
- `complete-ride`: Finish ride and process payment

#### ⭐ Rating System
- `rate-driver`: Riders rate drivers after completed rides
- `rate-rider`: Drivers rate riders after completed rides

#### 💰 Token Management
- `mint-tokens`: Mint new tokens (owner only)
- `transfer-tokens`: Transfer tokens between users

#### 📖 Read-Only Functions
- `get-driver`: Retrieve driver information
- `get-rider`: Retrieve rider information
- `get-ride`: Retrieve ride details
- `get-token-balance`: Check user's token balance

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity and Stacks blockchain

### Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd Tokenised-Ride-Sharing-System
```

2. Verify the contract:
```bash
clarinet check
```

3. Run tests (if available):
```bash
npm install
npm test
```

## 📋 Usage Examples

### 1. Register as a Driver
```clarity
(contract-call? .tokenised-ride-sharing-system register-driver "John Doe" "Toyota Camry 2020")
```

### 2. Register as a Rider
```clarity
(contract-call? .tokenised-ride-sharing-system register-rider "Jane Smith")
```

### 3. Request a Ride
```clarity
(contract-call? .tokenised-ride-sharing-system request-ride "Airport" "Downtown" u100)
```

### 4. Accept a Ride (Driver)
```clarity
(contract-call? .tokenised-ride-sharing-system accept-ride u1)
```

### 5. Complete a Ride
```clarity
(contract-call? .tokenised-ride-sharing-system complete-ride u1)
```

### 6. Rate a Driver
```clarity
(contract-call? .tokenised-ride-sharing-system rate-driver u1 u5)
```

## 🔄 Ride Flow

1. **🟢 Registration**: Both driver and rider register on the platform
2. **💰 Token Setup**: Riders acquire tokens for payments
3. **📱 Ride Request**: Rider creates a ride request with pickup, destination, and fare
4. **✅ Acceptance**: Available driver accepts the ride
5. **🚗 Start**: Driver starts the ride
6. **🏁 Completion**: Driver completes the ride, payment is transferred automatically
7. **⭐ Rating**: Both parties can rate each other

## 🎯 Error Codes

- `u100`: Unauthorized access
- `u101`: Already exists (duplicate registration)
- `u102`: Not found (user/ride doesn't exist)
- `u103`: Invalid status (wrong ride state)
- `u104`: Insufficient balance
- `u105`: Invalid amount/rating

## 🔒 Security Features

- **Permission Checks**: Only authorized users can perform specific actions
- **Balance Validation**: Ensures sufficient funds before ride requests
- **Status Validation**: Prevents invalid state transitions
- **Rating Bounds**: Enforces 1-5 star rating system

## 🛠️ Development

### Contract Structure
- **290 lines** of clean, minimal Clarity code
- **No comments** for production-ready appearance
- **LF line endings** for Clarinet compatibility
- **Comprehensive error handling**

### Testing
The contract includes proper error handling and validation for all edge cases. Consider writing comprehensive tests for:
- User registration edge cases
- Ride state transitions
- Token transfer scenarios
- Rating system validation

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

*Built with ❤️ on the Stacks blockchain*
