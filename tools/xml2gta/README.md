# xml2gta

Converts CodeWalker XML (`*.ydr.xml`, `*.ytyp.xml`, ...) into GTA V binary files on **Linux or Windows**, using CodeWalker.Core.

```
git clone https://github.com/dexyfex/CodeWalker
git clone https://github.com/sharpdx/SharpDX
# in CodeWalker.Core.csproj: target net8.0 and compile SharpDX.Mathematics + SharpDX/Mathematics/Interop sources
# instead of the NuGet packages (see the OSRP v1.0.8 commit for the exact changes)
dotnet run -c Release -- <xml folder> <output folder>
dotnet run -c Release -- verify <output folder>
```

OSRP pipeline: `map/blender/osijek_export_gta.py` (Blender + Sollumz, writes XML) → `xml2gta` (binary) → `fivem-resources/osrp_osijek_map/stream/`.
