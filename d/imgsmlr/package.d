/*-------------------------------------------------------------------------
 *
 *          Image similarity extension
 *
 * Copyright (c) 2015, PostgreSQL Global Development Group
 *
 * This software is released under the PostgreSQL Licence.
 *
 * Author: Alexander Korotkov <aekorotkov@gmail.com>
 *-------------------------------------------------------------------------
 */

module imgsmlr;

import core.stdc.math;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import std.algorithm.comparison : Min = min, Max = max;

enum PATTERN_SIZE = 64;
enum SIGNATURE_SIZE = 16;

struct PatternData
{
	float[PATTERN_SIZE][PATTERN_SIZE] values;
}

struct Signature
{
	float[SIGNATURE_SIZE] values;
}

/*
 * Extract signature from pattern.
 */
Signature* pattern2signature(PatternData* pattern)
{
	Signature *signature = cast(Signature *)malloc(Signature.sizeof);

	calcSignature(pattern, signature);

	debug(imgsmlr) debugPrintSignature(signature, "/tmp/signature.raw");

	return signature;
}

/*
 * Shuffle pattern values in order to make further comparisons less sensitive
 * to shift. Shuffling is actually a build of "w" radius in rectangle
 * "(x, y) - (x + sX, y + sY)".
 */
void
shuffle(PatternData *dst, PatternData *src, int x, int y, int sX, int sY, int w)
{
	int i, j;

	for (i = x; i < x + sX; i++)
	{
		for (j = y; j < y + sY; j++)
		{
			int ii, jj;
			int ii_min = Max(x, i - w),
				ii_max = Min(x + sX, i + w + 1),
				jj_min = Max(y, j - w),
				jj_max = Min(y + sY, j + w + 1);
			float sum = 0.0f, sum_r = 0.0f;

			for (ii = ii_min; ii < ii_max; ii++)
			{
				for (jj = jj_min; jj < jj_max; jj++)
				{
					float r = (i - ii) * (i - ii) + (j - jj) * (j - jj);
					r = 1.0f - sqrt(r) / cast(float)w;
					if (r <= 0.0f)
						continue;
					sum += src.values[ii][jj] * src.values[ii][jj] * r;
					sum_r += r;
				}
			}
			assert (sum >= 0.0f);
			assert (sum_r > 0.0f);
			dst.values[i][j] = sqrt(sum / sum_r);
		}
	}
}

/*
 * Shuffle pattern: call "shuffle" for each region of wavelet-transformed
 * pattern. For each region, blur radius is selected accordingly to its size;
 */
PatternData *shuffle_pattern(PatternData *patternSrc)
{
	PatternData *patternDst;
	int size = PATTERN_SIZE;

	patternDst = cast(PatternData *)malloc(PatternData.sizeof);
	memcpy(patternDst, patternSrc, PatternData.sizeof);

	while (size > 4)
	{
		size /= 2;
		shuffle(patternDst, patternSrc, size, 0, size, size, size / 4);
		shuffle(patternDst, patternSrc, 0, size, size, size, size / 4);
		shuffle(patternDst, patternSrc, size, size, size, size, size / 4);
	}

	debug(imgsmlr) debugPrintPattern(patternDst, "/tmp/pattern4.raw", false);

	return patternDst;
}

/*
 * Output for type "pattern": return textual representation of matrix.
 */
void pattern_out(PatternData *pattern, char *buf)
{
	int i, j;

	buf += sprintf(buf, "(");
	for (i = 0; i < PATTERN_SIZE; i++)
	{
		if (i > 0)
			buf += sprintf(buf, ", ");
		buf += sprintf(buf, "(");
		for (j = 0; j < PATTERN_SIZE; j++)
		{
			if (j > 0)
				buf += sprintf(buf, ", ");
			buf += sprintf(buf, "%f", pattern.values[i][j]);
		}
		buf += sprintf(buf, ")");
	}
	buf += sprintf(buf, ")");
}

/*
 * Output for type "signature": return textual representation of vector.
 */
void signature_out(Signature *signature, char *buf)
{
	int i;

	buf += sprintf(buf, "(");
	for (i = 0; i < SIGNATURE_SIZE; i++)
	{
		if (i > 0)
			buf += sprintf(buf, ", ");
		buf += sprintf(buf, "%f", signature.values[i]);
	}
	buf += sprintf(buf, ")");
}

/*
 * Calculate summary of square difference between "patternA" and "patternB"
 * in rectangle "(x, y) - (x + sX, y + sY)".
 */
float
calcDiff(PatternData *patternA, PatternData *patternB, int x, int y,
																int sX, int sY)
{
	int i, j;
	float summ = 0.0f, val;
	for (i = x; i < x + sX; i++)
	{
		for (j = y; j < y + sY; j++)
		{
			val =   patternA.values[i][j]
			      - patternB.values[i][j];
			summ += val * val;
		}
	}
	return summ;
}

/*
 * Distance between patterns is square root of the summary of difference between
 * regions of wavelet-transformed pattern corrected by their sized. Difference
 * of each region is summary of square difference between values.
 */
float pattern_distance(PatternData* patternA, PatternData* patternB)
{
	float distance = 0.0f, val;
	int size = PATTERN_SIZE;
	float mult = 1.0f;

	while (size > 1)
	{
		size /= 2;
		distance += mult * calcDiff(patternA, patternB, size, 0, size, size);
		distance += mult * calcDiff(patternA, patternB, 0, size, size, size);
		distance += mult * calcDiff(patternA, patternB, size, size, size, size);
		mult *= 2.0f;
	}
	val = patternA.values[0][0] - patternB.values[0][0];
	distance += mult * val * val;
	distance = sqrt(distance);

	return distance;
}

/*
 * Distance between signatures: mean-square difference between signatures.
 */
float signature_distance(Signature *signatureA, Signature *signatureB)
{
	float distance = 0.0f, val;
	int i;

	for (i = 0; i < SIGNATURE_SIZE; i++)
	{
		val = signatureA.values[i] - signatureB.values[i];
		distance += val * val;
	}
	distance = sqrt(distance);

	return distance;
}

/*
 * Normalize pattern: make it minimal value equal to 0 and
 * maximum value equal to 1.
 */
void
normalizePattern(PatternData *pattern)
{
	float min = 1.0f, max = 0.0f, val;
	int i, j;
	for (i = 0; i < PATTERN_SIZE; i++)
	{
		for (j = 0; j < PATTERN_SIZE; j++)
		{
			val = pattern.values[i][j];
			if (val < min) min = val;
			if (val > max) max = val;

		}
	}
	for (i = 0; i < PATTERN_SIZE; i++)
	{
		for (j = 0; j < PATTERN_SIZE; j++)
		{
			pattern.values[i][j] = (pattern.values[i][j] - min) / (max - min);
		}
	}
}

/*
 * Do Haar wavelet transform over pattern.
 */
void
waveletTransform(PatternData *dst, PatternData *src, int size)
{
	if (size > 1)
	{
		int i, j;
		size /= 2;
		for (i = 0; i < size; i++)
		{
			for (j = 0; j < size; j++)
			{
				dst.values[i + size][j] =        ( - src.values[2 * i][2 * j]     + src.values[2 * i + 1][2 * j]
				                                    - src.values[2 * i][2 * j + 1] + src.values[2 * i + 1][2 * j + 1]) / 4.0f;
				dst.values[i][j + size] =        ( - src.values[2 * i][2 * j]     - src.values[2 * i + 1][2 * j]
				                                    + src.values[2 * i][2 * j + 1] + src.values[2 * i + 1][2 * j + 1]) / 4.0f;
				dst.values[i + size][j + size] = (   src.values[2 * i][2 * j]     - src.values[2 * i + 1][2 * j]
				                                    - src.values[2 * i][2 * j + 1] + src.values[2 * i + 1][2 * j + 1]) / 4.0f;
			}
		}
		for (i = 0; i < size; i++)
		{
			for (j = 0; j < size; j++)
			{
				src.values[i][j] =               (   src.values[2 * i][2 * j]     + src.values[2 * i + 1][2 * j]
				                                    + src.values[2 * i][2 * j + 1] + src.values[2 * i + 1][2 * j + 1]) / 4.0f;
			}
		}
		waveletTransform(dst, src, size);
	}
	else
	{
		dst.values[0][0] = src.values[0][0];
	}
}

/*
 * Calculate summary of squares in rectangle "(x, y) - (x + sX, y + sY)".
 */
float
calcSumm(PatternData *pattern, int x, int y, int sX, int sY)
{
	int i, j;
	float summ = 0.0f, val;
	for (i = x; i < x + sX; i++)
	{
		for (j = y; j < y + sY; j++)
		{
			val = pattern.values[i][j];
			summ += val * val;
		}
	}
	return sqrt(summ);
}

/*
 * Make short signature from pattern.
 */
void
calcSignature(PatternData *pattern, Signature *signature)
{
	int size = PATTERN_SIZE;
	int i = 0;
	float mult = 1.0f;
	while (size > 1)
	{
		size /= 2;
		if (i == 0)
		{
			signature.values[0] = mult * calcSumm(pattern, size, 0, size, size);
			signature.values[0] = mult * calcSumm(pattern, 0, size, size, size);
			signature.values[0] = mult * calcSumm(pattern, size, size, size, size);
			i++;
		}
		else
		{
			signature.values[i++] = mult * calcSumm(pattern, size, 0, size, size);
			signature.values[i++] = mult * calcSumm(pattern, 0, size, size, size);
			signature.values[i++] = mult * calcSumm(pattern, size, size, size, size);
		}
		mult *= 2.0f;
	}
}

debug(imgsmlr)
{
	
void
debugPrintPattern(PatternData *pattern, const char *filename, bool color)
{
	int i, j;
	FILE *output = fopen(filename, "wb");
	for (j = 0; j < PATTERN_SIZE; j++)
	{
		for (i = 0; i < PATTERN_SIZE; i++)
		{
			float val = pattern.values[i][j];
			if (!color)
			{
				fputc(cast(int)(val * 255.999f), output);
				fputc(cast(int)(val * 255.999f), output);
				fputc(cast(int)(val * 255.999f), output);
			}
			else
			{
				if (val >= 0.0f)
				{
					fputc(0, output);
					fputc(cast(int)(val * 255.999f), output);
					fputc(0, output);
				}
				else
				{
					fputc(cast(int)(- val * 255.999f), output);
					fputc(0, output);
					fputc(0, output);
				}
			}
		}
	}
	fclose(output);
}

void
debugPrintSignature(Signature *signature, const char *filename)
{
	int i;
	float max = 0.0f;
	FILE *output = fopen(filename, "wb");

	for (i = 0; i < SIGNATURE_SIZE; i++)
	{
		max = Max(max, signature.values[i]);
	}

	for (i = 0; i < SIGNATURE_SIZE; i++)
	{
		float val = signature.values[i];
		val = val / max;
		fputc(cast(int)(val * 255.999f), output);
		fputc(cast(int)(val * 255.999f), output);
		fputc(cast(int)(val * 255.999f), output);
	}
	fclose(output);
}

}
