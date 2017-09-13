#include "imgsmlr_lib.h"

int main(int argc, char** argv)
{
	if (argc == 1)
	{
		fprintf(stderr, "Usage: %s FILE [FILE]...\n", argv[0]);
		return 1;
	}
	else
	{
		PatternData **patterns = calloc(argc-1, sizeof(PatternData*));
		PatternData **shuffled_patterns = calloc(argc-1, sizeof(PatternData*));
		Signature **signatures = calloc(argc-1, sizeof(Signature*));
		Signature **shuffled_signatures = calloc(argc-1, sizeof(Signature*));
		for (int i = 0; i < argc-1; i++)
		{
			FILE *f = fopen(argv[1+i], "rb");
			fseek(f, 0, SEEK_END);
			size_t size = ftell(f);
			fseek(f, 0, SEEK_SET);
			void *data = malloc(size);
			fread(data, size, 1, f);
			fclose(f);

			char *ext = strrchr(argv[1+i], '.');
			if (!strcasecmp(ext, ".jpg") || !strcasecmp(ext, ".jpeg"))
				patterns[i] = jpeg2pattern(data, size);
			else if (!strcasecmp(ext, ".png"))
				patterns[i] = png2pattern(data, size);
			else if (!strcasecmp(ext, ".gif"))
				patterns[i] = gif2pattern(data, size);
			else
			{
				fprintf(stderr, "Unknown image extension: %s\n", argv[1+i]);
				return 1;
			}

			free(data);

			shuffled_patterns[i] = shuffle_pattern(patterns[i]);
			signatures[i] = pattern2signature(patterns[i]);
			shuffled_signatures[i] = pattern2signature(shuffled_patterns[i]);

			/*
			printf("%s:\n", argv[1+i]);
			char *buf = malloc(1024*1024);
			pattern_out(patterns[i], buf); printf("\tPattern: %s\n", buf);
			pattern_out(shuffled_patterns[i], buf); printf("\tShuffled pattern: %s\n", buf);
			signature_out(         signatures[i], buf); printf("\tSignature         : %s\n", buf);
			signature_out(shuffled_signatures[i], buf); printf("\tShuffled signature: %s\n", buf);
			free(buf);
			*/

			for (int j = 0; j < i; j++)
			{
				printf("%s / %s: %f %f %f %f\n",
					argv[1+j], argv[1+i],
					pattern_distance(patterns[i], patterns[j]),
					pattern_distance(shuffled_patterns[i], shuffled_patterns[j]),
					signature_distance(signatures[i], signatures[j]),
					signature_distance(shuffled_signatures[i], shuffled_signatures[j])
				);
			}
		}
	}
}
