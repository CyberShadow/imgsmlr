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

module imgsmlr.gd;

import gd.gd; // https://github.com/CyberShadow/afb-d/tree/cybershadow/gd

import core.stdc.math;
import core.stdc.stdio;
import core.stdc.stdlib;

import imgsmlr;

/*
 * Transform GD image into pattern.
 */
PatternData *
image2pattern(gdImagePtr im)
{
	gdImagePtr	tb;
	PatternData *pattern;
	PatternData source;

	/* Resize image */
	tb = gdImageCreateTrueColor(PATTERN_SIZE, PATTERN_SIZE);
	if (!tb)
	{
		fprintf(stderr, "Error creating pattern\n");
		return null;
	}
	gdImageCopyResampled(tb, im, 0, 0, 0, 0, PATTERN_SIZE, PATTERN_SIZE,
			im.sx, im.sy);

	/* Create source pattern as greyscale image */
	makePattern(tb, &source);
	gdImageDestroy(tb);

	debug(imgsmlr)
	debugPrintPattern(&source, "/tmp/pattern1.raw", false);

	/* "Normalize" intensiveness in the pattern */
	normalizePattern(&source);

	debug(imgsmlr)
	debugPrintPattern(&source, "/tmp/pattern2.raw", false);

	/* Allocate pattern */
	pattern = cast(PatternData *)malloc(PatternData.sizeof);

	/* Do wavelet transform */
	waveletTransform(pattern, &source, PATTERN_SIZE);

	debug(imgsmlr)
	debugPrintPattern(pattern, "/tmp/pattern3.raw", true);

	return pattern;
}

/*
 * Load pattern from jpeg image.
 */
PatternData* jpeg2pattern(void *imgData, size_t imgSize)
{
	PatternData *pattern;
	gdImagePtr im;

	im = gdImageCreateFromJpegPtr(cast(int)imgSize, imgData);
	if (!im)
	{
		fprintf(stderr, "Error loading jpeg\n");
		return null;
	}
	pattern = image2pattern(im);
	gdImageDestroy(im);

	return pattern;
}

/*
 * Load pattern from png image.
 */
PatternData* png2pattern(void *imgData, size_t imgSize)
{
	PatternData *pattern;
	gdImagePtr im;

	im = gdImageCreateFromPngPtr(cast(int)imgSize, imgData);
	if (!im)
	{
		fprintf(stderr, "Error loading png\n");
		return null;
	}
	pattern = image2pattern(im);
	gdImageDestroy(im);

	return pattern;
}

/*
 * Load pattern from gif image.
 */
PatternData* gif2pattern(void *imgData, size_t imgSize)
{
	PatternData *pattern;
	gdImagePtr im;

	im = gdImageCreateFromGifPtr(cast(int)imgSize, imgData);
	if (!im)
	{
		fprintf(stderr, "Error loading gif\n");
		return null;
	}
	pattern = image2pattern(im);
	gdImageDestroy(im);

	return pattern;
}

/*
 * Make pattern from gd image.
 */
void
makePattern(gdImagePtr im, PatternData *pattern)
{
	int i, j;
	for (i = 0; i < PATTERN_SIZE; i++)
		for (j = 0; j < PATTERN_SIZE; j++)
		{
			int pixel = gdImageGetTrueColorPixel(im, i, j);
			float red = cast(float) gdTrueColorGetRed(pixel) / 255.0,
				  green = cast(float) gdTrueColorGetGreen(pixel) / 255.0,
				  blue = cast(float) gdTrueColorGetBlue(pixel) / 255.0;
			pattern.values[i][j] = sqrt((red * red + green * green + blue * blue) / 3.0f);
		}
}

