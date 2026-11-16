# Staging launch catalogue source coverage

The staging import loaded 4,832 of the 5,020 launch manifest films. This investigation covers the 188 held titles.

## Narrative-source investigation

Replayed the current parser against all 188 current English Wikipedia revisions, validating the page's Wikidata ID against the manifest and the parsed page and revision IDs. Every case reproduced `insufficient_context`. This was a read-only investigation. No Registry code, staging rows or assignment jobs changed.

- **11 English article headings cover the film.** The retained paragraphs include prose under `Summary`, `Plot outline`, plural or qualified plot headings, and anthology segment headings. The candidates are Holidays (323262), Three... Extremes (33908), Butchers (720026), Asylum (25993), Trilogy of Terror (38783), All Hallows' Eve 2 (361043), The Strange World of Coffin Joe (107016), Three (54117), Over Your Dead Body (199925), The Playgirls and the Vampire (37678) and Midnight Movies (36883). Accept explicit narrative aliases and identify anthology sections in context. Generic labels such as `Overview` and `Films` should require film-specific evidence. Butchers has a 33-word premise, so passing the readiness check would still give it limited context. [Holidays](https://en.wikipedia.org/wiki/Holidays_(2016_film)) · [Three... Extremes](https://en.wikipedia.org/wiki/Three..._Extremes)
- **One English article puts its synopses in a table.** Urban Myths (957154) has a labelled Synopsis column under Stories. Registry removes tables before reading paragraphs. A targeted extraction of the synopsis cells could preserve the episode title and prose without ingesting cast or unrelated tables. [Urban Myths](https://en.wikipedia.org/wiki/Urban_Myths_(film))
- **A broader Wikipedia fallback needs a source-policy change.** 98 films have a matching original-language article. A heading screen found plot-like headings on 73 of those, including 71 beyond the English article fixes. This is a candidate count, since film scope, nonempty prose and source quality need validation. The French pages for Some Like It Rare and Final Cut contain film synopses. The importer would need locale-aware headings and exclusions, revision URLs and provenance that retain the original language. Recheck assignment behaviour with the chosen source language before using it for batch assessments. 164 films have a sitelink in at least one other Wikipedia edition, and 24 have none. These counts overlap the English fixes. [Barbaque](https://fr.wikipedia.org/wiki/Barbaque) · [Coupez !](https://fr.wikipedia.org/wiki/Coupez_!_(film))
- **English introductions and other sources vary in coverage.** 43 pages explicitly carry a missing-plot notice. Some Like It Rare still has a short premise in its lead, while The Advent Calendar's lead identifies the film without describing its events. Accepting narrative in leads or a documentary's description would require a separate evidence rule. For films with no adequate Wikipedia narrative, retaining the exact launch list requires a film-specific alternative source and provenance, or a deliberate change to the current no-partial-import rule. A factual or promotional one-liner gives limited support for qualities.
- **Entity agreement can still identify the wrong work.** The English Dogra Magra article covers the novel. Its Overview describes the novel and the film appears under Adaptations. Verify the film scope of source passages or use a film-specific source before considering a heading or locale change for this entry. [Dogra Magra article](https://en.wikipedia.org/wiki/Dogra_Magra) · [National Film Archive of Japan record](https://nfad.nfaj.go.jp/det.php?data_id=66163)

The smallest Registry change would handle explicit narrative headings and verified anthology sections, with regression cases for misleading headings and adaptation articles. Table extraction and multilingual sources have distinct retrieval and validation requirements. Retry only the IDs covered by each approved change.

### Follow-up direction

- The live TMDB movie-keywords check found `anthology` (9706) or `horror anthology` (250593) on all eight reviewed anthology cases, including Urban Myths. Use these keywords as format hints. Confirm narrative structure in the matching Wikipedia article and allow clear narrative structure to establish the format when TMDB lacks a tag. For a table like Urban Myths, extract segment titles and the explicitly labelled synopsis cells, preserving order and revision provenance. [TMDB movie keywords](https://developer.themoviedb.org/reference/movie-keywords) · [Urban Myths](https://en.wikipedia.org/wiki/Urban_Myths_(film))
- Prefer testing the pinned Jev model on original-language text before adding translation. Compare the same film and the same revision's passages with a reviewed English translation against evidence-backed expected qualities. TypeSafe reports multilingual improvements in Jev 1.14.0. Glutton has yet to test the relevant languages. If translation is needed, retain it as a derived record keyed to the exact source revision and original paragraph IDs. [Jev 1.14 release](https://typesafe.ai/blog/jev-1-14) · [OpenAI structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- The owner wants films with verified TMDB metadata and no usable Wikipedia narrative to remain available in Library and to be identified for community editing. This changes the existing import contract. Keep quality assignment gated on usable context and record the source gap. Identify community-edit candidates from confirmed editorial gaps, preserving the distinction between a missing article and an existing article that needs a plot. Provider outages and extractor defects are operational issues.

## Films held for narrative context

Each film below returned `wikipedia:insufficient_context`. The manifest retains all selected IDs.


| TMDB ID | Film |
| --- | --- |
| 730769 | Some Like It Rare |
| 323262 | Holidays |
| 852438 | Final Cut |
| 33908 | Three... Extremes |
| 762079 | The Advent Calendar |
| 926980 | The Privilege |
| 600184 | The Nest |
| 741998 | The Binding |
| 720026 | Butchers |
| 982752 | American Carnage |
| 586586 | Bliss |
| 463322 | The Dark |
| 25993 | Asylum |
| 630720 | Dark Glasses |
| 403642 | The Neighbor |
| 38783 | Trilogy of Terror |
| 56811 | Cropsey |
| 850920 | The Parenting |
| 387399 | We Go On |
| 506775 | Nekrotronic |
| 409164 | Boys in the Trees |
| 1082063 | Amelia’s Children |
| 422708 | Let the Corpses Tan |
| 1241624 | Ghost Train |
| 879957 | Wyrmwood: Apocalypse |
| 724885 | The Cursed: Dead Man's Prey |
| 530157 | Pledge |
| 361043 | All Hallows' Eve 2 |
| 794234 | The Bunker Game |
| 467405 | Don't Sleep |
| 1244953 | Trust |
| 1072074 | Disquiet |
| 1088157 | Godless: The Eastfield Exorcism |
| 56386 | SS Experiment Love Camp |
| 484436 | Animas |
| 1286185 | The Carpenter's Son |
| 84228 | Julia X |
| 24868 | Offspring |
| 761830 | The Guest Room |
| 1027385 | Dangerous Game: The Legacy Murders |
| 631947 | The Legend of La Llorona |
| 78093 | Alyce Kills |
| 586577 | In Search of Darkness |
| 534235 | 14 Cameras |
| 363689 | The Unspoken |
| 438982 | Game of Death |
| 86305 | Exit Humanity |
| 396004 | The Evil in Us |
| 360007 | Patchwork |
| 53186 | Morgiana |
| 29342 | The Bees |
| 519238 | Murder Me, Monster |
| 704269 | Skull: The Mask |
| 59912 | Black Magic Rites |
| 560842 | Achoura |
| 107016 | The Strange World of Coffin Joe |
| 461775 | The Laplace's Demon |
| 80448 | 99.9: The Frequency of Terror |
| 247418 | Sundel Bolong |
| 96001 | Hard Labor |
| 178239 | Morianna |
| 386303 | I Like Bats |
| 73636 | Plaga zombie |
| 86985 | ID:A |
| 285554 | Norway |
| 426958 | Strangled |
| 362262 | Idyll |
| 854196 | Zalava |
| 865576 | It Hatched |
| 848483 | Flowing |
| 1202867 | In the Name of God |
| 110345 | Dead Sushi |
| 469036 | Vidar the Vampire |
| 16032 | Midsummer |
| 664594 | Kill It and Leave This Town |
| 16036 | Taoism Drunkard |
| 40105 | Dr. Lamb |
| 518148 | Kanika |
| 347344 | Alena |
| 279859 | The Bellman |
| 183216 | Tiyanak |
| 359701 | Naciye |
| 1516534 | Roqia |
| 1079122 | Hungry Ghost Diner |
| 1487113 | Sardaarji 3 |
| 62932 | The Curse of the Crying Woman |
| 54117 | Three |
| 480812 | Raju Gari Gadhi 2 |
| 40226 | Vampire Hunters |
| 153820 | The Girl from Nowhere |
| 672437 | Brain Freeze |
| 15831 | Cecilie |
| 471445 | Motorrad |
| 633811 | Bloodsuckers |
| 751494 | Manne No 13 |
| 548392 | Sword of God |
| 717601 | Karimpoocha |
| 164993 | Shopping Tour |
| 36166 | Devilman |
| 84387 | Don't Panic |
| 91229 | Dogra Magra |
| 104819 | Orozco the Embalmer |
| 51868 | Shaolin vs. Evil Dead |
| 10370 | Premutos: The Fallen Angel |
| 640196 | Signal 100 |
| 67903 | Ubaldo Terzani Horror Show |
| 471331 | Paisa Vasool |
| 36835 | Oasis of the Zombies |
| 199925 | Over Your Dead Body |
| 154529 | Happy Ghost II |
| 81189 | Love Letters of a Portuguese Nun |
| 29954 | Body Puzzle |
| 1233199 | Exorcism Chronicles: The Beginning |
| 320714 | Yeh Raat Phir Na Aayegi |
| 386835 | The Forest |
| 84362 | Devil Hunter |
| 40151 | Plaga Zombie: Mutant Zone |
| 131824 | Finger of Doom |
| 604767 | Saaya |
| 87503 | Eugenie... The Story of Her Journey into Perversion |
| 93752 | Two Undercover Angels |
| 50538 | Evil Words |
| 580605 | Ouija |
| 1355126 | Sugar Mill |
| 66664 | Shocking Dark |
| 5844 | Alive |
| 600650 | Where Is The Venkatalakshmi |
| 125176 | Kiss Me Monster |
| 119471 | Zombie 108 |
| 45270 | Saint Martyrs of the Damned |
| 623545 | Gimmick |
| 957154 | Urban Myths |
| 37223 | Onechanbara: Bikini Samurai Squad |
| 28298 | Eugenie de Sade |
| 1193626 | Pindam |
| 242493 | The Bloodiest |
| 28835 | The Vengeance of Dr. Mabuse |
| 142410 | Room 205 of Fear |
| 120194 | Childish Games |
| 86645 | The Demons |
| 133985 | Horror Stories |
| 460456 | Andhhagadu |
| 19130 | The Invisible Dr. Mabuse |
| 64447 | Karmina 2 |
| 52849 | Bell from Hell |
| 744876 | Kaali Khuhi |
| 141442 | The Living Coffin |
| 78382 | Superstitions |
| 546764 | The Supernatural Events on Campus |
| 86640 | Massacre in Dinosaur Valley |
| 278438 | The Last Supper |
| 64112 | Aatma |
| 282942 | The Phantom of the Red House |
| 70411 | Orgies of Edo |
| 185843 | The Strangler |
| 336265 | The Mind's Eye |
| 108790 | St. John's Wort |
| 104308 | The Spider Labyrinth |
| 137625 | Nocturne 29 |
| 718558 | Fried Barry |
| 182921 | The Snake Girl and the Silver-Haired Witch |
| 106505 | The Butcher |
| 40039 | Spiders |
| 85171 | Too Beautiful to Die |
| 401065 | The Axe Murders of Villisca |
| 67219 | The Great Alligator |
| 62947 | The Witch |
| 37678 | The Playgirls and the Vampire |
| 281152 | Lady Morgan's Vengeance |
| 159638 | Ghost Team One |
| 225029 | Challenge the Devil |
| 142030 | The Seventh Grave |
| 36883 | Midnight Movies: From the Margin to the Mainstream |
| 99449 | The Iguana with the Tongue of Fire |
| 18616 | No Man's Land: The Rise of Reeker |
| 18044 | Ogre |
| 26334 | Run! Bitch Run! |
| 821390 | The Retreat |
| 521113 | Black Site |
| 688343 | The Curse of Audrey Earnshaw |
| 521509 | Extremity |
| 738370 | Hosts |
| 611640 | The Deeper You Dig |
| 526052 | Becoming |
| 95091 | Dr. Terror's Gallery of Horrors |
| 550273 | Boo! |
| 18556 | Steel Trap |
| 387501 | Peelers |
