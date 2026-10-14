using System.Text;
using AngleSharp.Html.Parser;
using OrchidApp.Web.Services;

var passed = 0;
void Check(string name, bool result) { if (!result) throw new Exception(name); Console.WriteLine("PASS " + name); passed++; }
string Save(string html) => RichNotes.PrepareForSave(RichNotes.Marker + html)!;
void Reject(string name, string input) { try { RichNotes.PrepareForSave(input); throw new Exception(name); } catch (ArgumentException) { Check(name, true); } }

var legacy = "Use <orchid> & water\r\nSecond line";
var savedLegacy = RichNotes.PrepareForSave(legacy)!;
Check("Legacy angle brackets remain literal", savedLegacy.Contains("&lt;orchid&gt;") && savedLegacy.Contains("&amp;"));
Check("Legacy line breaks preserved", savedLegacy.Contains("<br>"));
Check("Existing content is not inferred to be HTML", RichNotes.EditorHtml("<strong>literal</strong>").Contains("&lt;strong&gt;"));
var rich = Save("<p><strong>Bold</strong> <em>italic</em> <u>underline</u></p><ul><li>Bullet</li></ul><ol><li>Number</li></ol>");
Check("Formatting and both list types survive", rich.Contains("<ul>") && rich.Contains("<ol>") && rich.Contains("<u>underline</u>"));
Check("Repeated save is stable", RichNotes.PrepareForSave(rich) == rich);
var hostile = Save("<p style='color:red' onclick='alert(1)'>Safe<img src=x onerror='alert(1)'><iframe src='x'></iframe><script>alert(1)</script></p>");
var doc = new HtmlParser().ParseDocument(RichNotes.EditorHtml(hostile));
Check("Unsafe tags removed", doc.QuerySelector("script,img,iframe,style,svg") == null);
Check("Attributes removed", doc.All.All(e => e.Attributes.Length == 0));
Check("Word spans retain their words", Save("<p><span style='font:foo'>Copied words</span></p>").Contains("Copied words"));
var unicode = Save("<p>Floração tre\u0300s £ € ’ 🌸\u00A0A\u200BB\u2060C\uFEFFD\u0001</p>");
Check("Accents punctuation and emoji preserved", unicode.Contains("Floração très £ € ’ 🌸 ABCD"));
Check("Legacy unicode also cleaned", RichNotes.PrepareForSave("tre\u0300s\u00A0bien\u200B")!.Contains("très bien"));
Check("Joiners used by emoji preserved", Save("<p>👩‍🌾</p>").Contains("👩‍🌾"));
Check("Empty rich content becomes null", RichNotes.PrepareForSave(RichNotes.Marker + "<p><br></p>") == null);
Check("Whitespace becomes null", RichNotes.PrepareForSave("  \r\n ") == null);
Reject("Visible length limit", RichNotes.Marker + "<p>" + new string('x', 10001) + "</p>");
Reject("Raw paste limit", new string('x', RichNotes.MaxInputLength + 1));
Reject("UTF8 storage limit", RichNotes.Marker + string.Concat(Enumerable.Repeat("<p>x</p>", 8000)));
Check("HTML-encoded attacks remain text", Save("<p>&lt;img src=x onerror=alert(1)&gt;</p>").Contains("&lt;img"));
Check("Stored byte budget includes marker", Encoding.UTF8.GetByteCount(rich) < RichNotes.MaxStorageBytes);
Console.WriteLine($"{passed} checks passed.");
