'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { toast } from 'sonner';

export default function Page() {
  const [v, setV] = useState('');

  return (
    <main className="p-6">
      <Card>
        <CardContent className="space-y-4 p-6">
          <Input
            value={v}
            onChange={(e) => setV(e.target.value)}
            placeholder="type..."
          />
          <Button onClick={() => toast(`value: ${v || '(empty)'}`)}>
            Toast
          </Button>
        </CardContent>
      </Card>
    </main>
  );
}
