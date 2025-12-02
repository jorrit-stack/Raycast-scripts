const { render, screen } = require('@testing-library/react');
const BoltUserIdCapture = require('../bolt-user-id-capture');

test('renders Bolt User ID Capture component', () => {
	render(<BoltUserIdCapture />);
	const linkElement = screen.getByText(/Bolt User ID Capture/i);
	expect(linkElement).toBeInTheDocument();
});