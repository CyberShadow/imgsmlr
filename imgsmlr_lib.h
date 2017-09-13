/*-------------------------------------------------------------------------
 *
 *          Image similarity extension
 *
 * Copyright (c) 2015, PostgreSQL Global Development Group
 *
 * This software is released under the PostgreSQL Licence.
 *
 * Author: Alexander Korotkov <aekorotkov@gmail.com>
 *
 * IDENTIFICATION
 *    imgsmlr/imgsmlr_lib.h
 *-------------------------------------------------------------------------
 */
#include "imgsmlr.h"

#include <gd.h>
#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <string.h>

#define DEBUG_PRINT

PatternData* jpeg2pattern(void *imgData, size_t imgSize);
PatternData* png2pattern(void *imgData, size_t imgSize);
PatternData* gif2pattern(void *imgData, size_t imgSize);
Signature* pattern2signature(PatternData* pattern);
PatternData *shuffle_pattern(PatternData *patternSrc);
void pattern_out(PatternData *pattern, char *buf);
void signature_out(Signature *signature, char *buf);
float pattern_distance(PatternData* patternA, PatternData* patternB);
float signature_distance(Signature *signatureA, Signature *signatureB);

PatternData *image2pattern(gdImagePtr im);
void makePattern(gdImagePtr im, PatternData *pattern);
void normalizePattern(PatternData *pattern);
void waveletTransform(PatternData *dst, PatternData *src, int size);
float calcSumm(PatternData *pattern, int x, int y, int sX, int sY);
void calcSignature(PatternData *pattern, Signature *signature);
float calcDiff(PatternData *patternA, PatternData *patternB, int x, int y, int sX, int sY);
void shuffle(PatternData *dst, PatternData *src, int x, int y, int sX, int sY, int w);

#ifdef DEBUG_INFO
void debugPrintPattern(PatternData *pattern, const char *filename, bool color);
void debugPrintSignature(Signature *signature, const char *filename);
#endif
