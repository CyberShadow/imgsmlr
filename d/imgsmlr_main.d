import std.exception;
import std.file;
import std.parallelism;
import std.path;
import std.stdio;

import imgsmlr;
import imgsmlr.gd;

int main(string[] args)
{
	if (args.length == 1)
	{
		stderr.writefln("Usage: %s FILE [FILE]...\n", args[0]);
		return 1;
	}
	else
	{
		static struct Info
		{
			string fn;
			PatternData* pattern, shuffledPattern;
			Signature* signature, shuffledSignature;
		}
		Info[] data = taskPool.amap!((string fn)
			{
				Info info;
				info.fn = fn;
				auto data = read(fn);
				switch (fn.extension)
				{
					case ".jpg":
					case ".jpeg":
						info.pattern = jpeg2pattern(data.ptr, data.length);
						break;
					case ".png":
						info.pattern = png2pattern(data.ptr, data.length);
						break;
					case ".gif":
						info.pattern = gif2pattern(data.ptr, data.length);
						break;
					default:
						throw new Exception("Unknown image extension: " ~ fn);
				}
				enforce(info.pattern, "Error loading file: " ~ fn);

				info.shuffledPattern = shuffle_pattern(info.pattern);
				info.signature = pattern2signature(info.pattern);
				info.shuffledSignature = pattern2signature(info.shuffledPattern);
				return info;
			})(args[1..$]);

		foreach (i, ref a; data)
			foreach (j, ref b; data[0..i])
			{
				writefln("%s / %s: %f %f %f %f",
					b.fn, a.fn,
					pattern_distance(a.pattern, b.pattern),
					pattern_distance(a.shuffledPattern, b.shuffledPattern),
					signature_distance(a.signature, b.signature),
					signature_distance(a.shuffledSignature, b.shuffledSignature),
				);
			}
	}
	return 0;
}
