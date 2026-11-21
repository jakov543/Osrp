// xml2gta: converts CodeWalker XML (*.ydr.xml, *.ytyp.xml ...) to GTA V binary files using CodeWalker.Core
using System;
using System.IO;
using System.Xml;
using CodeWalker.GameFiles;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length >= 2 && args[0] == "verify") return Verify(args[1]);
        if (args.Length < 2) { Console.WriteLine("usage: xml2gta <inDir> <outDir> | verify <dir>"); return 1; }
        string inDir = args[0], outDir = args[1];
        Directory.CreateDirectory(outDir);
        int ok = 0, bad = 0;
        foreach (var path in Directory.GetFiles(inDir, "*.xml"))
        {
            var fname = Path.GetFileName(path);
            try
            {
                var fmt = XmlMeta.GetXMLFormat(fname.ToLowerInvariant(), out int trim);
                var doc = new XmlDocument();
                doc.LoadXml(File.ReadAllText(path));
                var stem = fname.Substring(0, fname.Length - trim);           // e.g. osijek_0_0.ydr
                var texFolder = Path.Combine(inDir, stem.Substring(0, stem.LastIndexOf('.')));
                var data = XmlMeta.GetData(doc, fmt, Directory.Exists(texFolder) ? texFolder : inDir);
                if (data == null || data.Length == 0) throw new Exception("no data");
                File.WriteAllBytes(Path.Combine(outDir, stem), data);
                Console.WriteLine($"OK   {stem}  ({fmt}, {data.Length / 1024} KB)");
                ok++;
            }
            catch (Exception e)
            {
                Console.WriteLine($"FAIL {fname}: {e.Message}");
                bad++;
            }
        }
        Console.WriteLine($"done: {ok} ok, {bad} failed");
        return bad == 0 ? 0 : 2;
    }

    static int Verify(string dir)
    {
        int bad = 0, verts = 0, tex = 0, bounds = 0;
        foreach (var path in Directory.GetFiles(dir, "*.ydr"))
        {
            try
            {
                var data = File.ReadAllBytes(path);
                var entry = RpfFile.CreateResourceFileEntry(ref data, 0);
                entry.Name = Path.GetFileName(path);
                data = ResourceBuilder.Decompress(data);
                var y = new YdrFile();
                y.Load(data, entry);
                var d = y.Drawable;
                int v = 0;
                foreach (var m in d.AllModels) foreach (var g in m.Geometries) v += g.VerticesCount;
                int t = d.ShaderGroup?.TextureDictionary?.Textures?.data_items?.Length ?? 0;
                bool b = d.Bound != null;
                verts += v; tex += t; if (b) bounds++;
                if (v == 0 || t == 0 || !b) { Console.WriteLine($"WARN {entry.Name}: verts={v} tex={t} bound={b}"); }
            }
            catch (Exception e) { Console.WriteLine($"BAD  {Path.GetFileName(path)}: {e.Message}"); bad++; }
        }
        var yt = new YtypFile();
        yt.Load(File.ReadAllBytes(Path.Combine(dir, "osijek.ytyp")));
        Console.WriteLine($"ytyp archetypes: {yt.AllArchetypes?.Length}  first: {yt.AllArchetypes?[0]?.Name}");
        Console.WriteLine($"ydr: {Directory.GetFiles(dir, "*.ydr").Length} files, {bad} unreadable, {verts} vertices, {tex} textures, {bounds} with collision");
        return bad == 0 ? 0 : 2;
    }
}
