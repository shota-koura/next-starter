import { render, screen } from '@testing-library/react';
import { Button } from '@/components/ui/button';

test('Button renders', () => {
  render(<Button>OK</Button>);
  expect(screen.getByRole('button', { name: 'OK' })).toBeInTheDocument();
});
