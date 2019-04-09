#include <stdio.h>
#include <stdint.h>

int main(void)
{
	const int bits = 20;
	const int max = (1 << bits)/2 - 1; // range is -max to +max
	const int shift = 5;
	const int shift_mask = (1 << shift) - 1;

	int x = max;
	int y = 0;

	const float k = 1.0;

	for(int i = 0 ; i < (1<<21) ; i++)
	{
		printf("%d %d\n", x, y);

		int xp = x + (y >> shift) - (x >> (2*shift+1));
		int yp = y - (x >> shift) - (y >> (2*shift+1)); // + (xacc >> shift);


#if 1
		if (xp > max)
		{
			x = max;
			y = 0;
		} else
		if (yp > max)
		{
			x = 0;
			y = max;
		} else
		if (yp < -max)
		{
			x = 0;
			y = -max;
		} else
		if (xp < -max)
		{
			x = -max;
			y = 0;
		} else
#endif
		{
			x = xp;
			y = yp;
		}
	}
}
