// Fuzz harness for gridsort (header-only qsort-compatible sort).
//
// Ported from the original fuzz/gridsort-fuzz.c, reworked because the old harness
// was broken: it memcpy'd up to `size` bytes into a fixed 16000-byte static buffer
// (harness-owned overflow on large inputs) and used a comparator returning uint8_t
// (always non-negative -> not a valid qsort comparator, so any "bug" it triggered
// was harness-induced). This version drives the same code path (gridsort()) with a
// valid total-order comparator, exercises all five element-size dispatch paths
// (gridsort8/16/32/64/128), and asserts the output is actually sorted.
//
// The 16-byte path is long double (x86 80-bit extended + 6 padding bytes): the sort
// moves those elements by long double assignment, which does NOT preserve the padding
// bytes, so its comparator/oracle must be value-based (like upstream's
// cmp_long_double), not byte-wise. The 1/2/4/8-byte paths move via integer types
// (bit-preserving), so memcmp is a valid total order there.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "../src/gridsort.h"

#define MAX_BYTES (1 << 18)

static size_t elem_size;

static int cmp_mem(const void *a, const void *b)
{
	return memcmp(a, b, elem_size);
}

static int cmp_ld(const void *a, const void *b)
{
	long double x = *(const long double *) a;
	long double y = *(const long double *) b;
	int xn = x != x;
	int yn = y != y;

	if (xn || yn)
		return xn - yn;

	return (x > y) - (x < y);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	static const size_t sizes[] = { 1, 2, 4, 8, 16 };
	size_t es, n, i;
	char *buf;
	CMPFUNC *cmp;

	if (size < 1)
		return 0;

	es = sizes[data[0] % 5];
	data++;
	size--;

	if (size > MAX_BYTES)
		size = MAX_BYTES;

	n = size / es;
	if (n == 0)
		return 0;

	buf = malloc(n * es);
	if (buf == NULL)
		return 0;

	memcpy(buf, data, n * es);

	elem_size = es;
	cmp = (es == 16) ? cmp_ld : cmp_mem;
	gridsort(buf, n, es, cmp);

	for (i = 1; i < n; i++)
	{
		if (cmp(buf + (i - 1) * es, buf + i * es) > 0)
			abort();
	}

	free(buf);

	return 0;
}
