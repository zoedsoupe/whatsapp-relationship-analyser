# whatsapp relationship analyzer

**because sometimes you need a spreadsheet to tell you if someone likes you**

## why i made this?

hi, i'm zoey! as a neurodivergent person who finds human relationships slightly more confusing than distributed systems architecture, i created this tool to help me understand what the heck is going on in my whatsapp conversations.

you know that feeling when you can't tell if someone sees you as a friend, a potential romantic partner, or just that person they accidentally added to their contacts? yeah, me too. so i did what any reasonable software engineer would do: i built an app that turns my social confusion into pretty charts.

this is for all of us who have ever stared at a text message for 20 minutes wondering "are they flirting or just being nice?" now you can stare at a radar chart of linguistic markers instead!

## what it does

this tool takes your exported whatsapp chats and transforms them into data-driven insights about your relationship:

- **relationship classification**: friend? romantic partner? person who tolerates you? now you'll know!
- **communication balance**: find out if you're the one carrying the conversation (we've all been there)
- **response time analysis**: discover if they're genuinely busy or just ignoring you
- **conversation patterns**: learn when you talk the most (spoiler: probably at 2 am when you should be sleeping)
- **linguistic markers**: see how often you both use romantic or intimate language

all wrapped up in pretty visualizations that make relationship anxiety look professional!

## super simple setup

### for the technically adventurous:

1. **prerequisites**: elixir (version 1.18+) and erlang/otp (27+)

2. **clone & setup**:
   ```bash
   git clone git@github.com:zoedsoupe/whatsapp-relationship-analyzer.git
   cd whatsapp-relationship-analyzer
   mix deps.get
   mix compile
   ```

3. **run livebook**:
   ```bash
   mix livebook.server
   ```

4. **get your chat data**:
   - open whatsapp
   - go to a chat and tap the three dots → more → export chat
   - choose "without media" (unless you want your computer to explode)
   - send it to yourself
   
5. **configure the runtime (very important!):**
   - open the "runtime settings" (sr keyboard shortcut)
   - select "attached node" as the runtime
   - you need to start the app with `iex --name <name>@<host> --cookie <secret> -S mix`
      - example: `iex --name whatsapp@127.0.0.1 --cookie zoey -S mix`
   - then fill the "name" and "cookie" fields and connect
   - evaluate the Analysis Cell, upload your `_chat.txt` and waits...

### for the "just let me try it" crowd:
i'm working on a phoenix web interface so you can just upload your chat online.

## how it works

as someone who finds comfort in understanding systems, here's how this one functions:

1. **chat parsing**: converts messy whatsapp exports into structured data (because timestamps are a nightmare)
2. **feature extraction**: identifies patterns in your messaging behavior 
3. **classification**: applies weighted scoring to determine relationship type
4. **visualization**: generates charts that make your relationship look like a scientific study

the system analyzes things that my brain struggles to pick up naturally:
- message frequency (are we talking a lot?)
- response times (do they reply quickly?)
- who initiates conversations (am i being annoying?)
- time patterns (do we chat at consistent times?)
- language markers (are we using "romantic" words?)

it's like having a social decoder ring for all those subtle cues i might miss!

## the future (if i hyperfocus on this project again)

here's what i might add:

- **web interface**: for people who don't want to set up elixir
- **more platforms**: because relationships happen in more places than just whatsapp
- **sentiment analysis**: to figure out if "fine" means fine or *fine*
- **time-series analysis**: to track how relationships change over time
- **custom classifications**: because relationships are complicated and unique
- **multi-person analysis**: compare how you communicate with different people

## final thoughts

this project combines my love for elixir, data, and trying to decode human interactions through logical means. is it a perfect way to understand relationships? probably not. is it better than staring at text messages and spiraling into anxiety? absolutely!

if you're like me and find people puzzling but find comfort in patterns and data, i hope this tool helps you make a little more sense of your digital connections.

remember: the best relationships probably can't be reduced to numbers and charts... but having numbers and charts sure is comforting when you're confused!

---

*built with love, confusion, and the elixir language by someone who finds code more predictable than people.*

*ps: if you use this and discover something surprising about a relationship, i'd love to hear about it (anonymized, of course). sometimes the data sees what we miss!*
