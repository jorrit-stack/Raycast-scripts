# Raycast Stripe Promo Code Checker

This project is a Raycast extension that allows users to check the validity of Stripe promo codes. It retrieves promo code details from the Stripe API and displays them in a user-friendly format.

## Features

- Check the status of a promo code.
- Retrieve detailed information about the promo code and associated coupon.
- Easy integration with Stripe API using a secure API key stored in the keychain.

## Installation

1. Clone the repository:

   ```
   git clone https://github.com/yourusername/raycast-stripe-promo-extension.git
   ```

2. Navigate to the project directory:

   ```
   cd raycast-stripe-promo-extension
   ```

3. Install the required dependencies:

   ```
   npm install
   ```

4. Add your Stripe API key to the macOS keychain:

   ```
   security add-generic-password -a 'stripe-api-key' -s 'raycast-stripe-api' -w 'YOUR_API_KEY_HERE'
   ```

## Usage

1. Open Raycast and type "Stripe Promo Code Checker".
2. Enter the promo code you wish to check.
3. View the results, including the promo code status, expiration date, and coupon details.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.