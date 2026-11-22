-- OSRP Osijek v1.0.25 - what the NPCs say in the dialog window (E near an NPC)
-- Every text has a Croatian (hr) and English (en) version; Config.NpcLanguage picks one.
-- Node: text (one text or a list = random one), opts = answers you can pick:
--   go = next node | act = 'gps' (arg = place) | 'heal' | 'buy' (arg = item) | 'id' | 'end'
-- {name} = NPC name, {flight} {time} {gate} = random flight info. "Goodbye" is always added.

OsijekDialogPlaces = {     -- local map coordinates (same as the Blender map) for act = 'gps'
    hospital = { -330, -372 }, airport = { 200, -425 }, beach = { -300, 278 }, tvrdja = { 225, 40 },
    promenade = { 0, 164 }, police = { -60, -381 }, gunshop = { 30, -385 }, stil = { -2, -386 }, volt = { 62, -386 }, park = { -150, 60 }, marina = { 140, 180 }, wreck = { 330, 175 },
}

local BYE = { hr = 'Doviđenja!', en = 'Goodbye!' }
OsijekDialogBye = BYE

-- shared answers about the city (citizens, travellers, staff use them)
local CITY = {
    city = { text = { hr = 'Osijek je najljepši grad na Dravi! Imamo Tvrđu, konkatedralu, promenadu i plažu Copacabanu. Što te zanima?',
                      en = 'Osijek is the most beautiful town on the Drava! We have Tvrđa, the cathedral, the promenade and the Copacabana beach. What are you into?' },
        opts = {
            { t = { hr = 'Gdje je plaža?', en = 'Where is the beach?' }, go = 'beach' },
            { t = { hr = 'Što je Tvrđa?', en = 'What is Tvrđa?' }, go = 'tvrdja' },
            { t = { hr = 'Gdje se mogu prošetati?', en = 'Where can I go for a walk?' }, go = 'walk' },
            { t = { hr = 'Ima li nešto pod vodom?', en = 'Is there anything under the water?' }, go = 'wreck' },
        } },
    beach = { text = { hr = 'Copacabana je na lijevoj obali Drave, preko pješačkog mosta. Ima skakaonicu od 3 i 5 metara!',
                       en = 'Copacabana is on the left bank of the Drava, over the footbridge. There is a 3 and 5 metre diving tower!' },
        opts = { { t = { hr = 'Postavi mi GPS do plaže.', en = 'Set my GPS to the beach.' }, act = 'gps', arg = 'beach', go = 'thanks' },
                 { t = { hr = 'Ima li tamo kafić?', en = 'Is there a bar?' }, go = 'beachbar' } } },
    beachbar = { text = { hr = 'Ima, beach bar odmah na pijesku. Limunada je odlična!', en = 'Yes, a beach bar right on the sand. The lemonade is great!' },
        opts = { { t = { hr = 'Super, idem tamo.', en = 'Great, I am going there.' }, act = 'gps', arg = 'beach', go = 'thanks' } } },
    tvrdja = { text = { hr = 'Tvrđa je stari barokni grad s trgom i konkatedralom svetog Petra i Pavla. Toranj ima skoro 100 metara.',
                        en = 'Tvrđa is the old baroque town with the square and the Co-cathedral of St. Peter and Paul. The tower is almost 100 metres tall.' },
        opts = { { t = { hr = 'Odvedi me tamo (GPS).', en = 'Take me there (GPS).' }, act = 'gps', arg = 'tvrdja', go = 'thanks' } } },
    walk = { text = { hr = 'Promenada uz Dravu je savršena, a s druge strane je šetalište s biciklističkom stazom. Bicikl možeš uzeti na stanici.',
                      en = 'The promenade by the Drava is perfect, and on the other side there is a walkway with a bike path. You can take a bike at the station.' },
        opts = { { t = { hr = 'GPS do promenade.', en = 'GPS to the promenade.' }, act = 'gps', arg = 'promenade', go = 'thanks' } } },
    wreck = { text = { hr = 'Kažu da na dnu Drave, istočno od mosta, leži stari teretni brod. Ronioci ga obožavaju.',
                       en = 'They say an old cargo boat lies on the bottom of the Drava, east of the bridge. Divers love it.' },
        opts = { { t = { hr = 'Pokaži mi gdje (GPS).', en = 'Show me where (GPS).' }, act = 'gps', arg = 'wreck', go = 'thanks' } } },
    hospital = { text = { hr = 'KBC Osijek je na jugu grada, kod Vukovarske. Ulaz u hitnu je desno od glavnog ulaza.',
                          en = 'KBC Osijek is in the south of the town. The emergency entrance is right of the main door.' },
        opts = { { t = { hr = 'Postavi GPS do bolnice.', en = 'Set GPS to the hospital.' }, act = 'gps', arg = 'hospital', go = 'thanks' } } },
    airport = { text = { hr = 'Zračna luka je sasvim na jugu, iza bolnice. Samo prati cestu prema jugu.',
                         en = 'The airport is at the far south, behind the hospital. Just follow the road south.' },
        opts = { { t = { hr = 'Postavi GPS do zračne luke.', en = 'Set GPS to the airport.' }, act = 'gps', arg = 'airport', go = 'thanks' } } },
    policegps = { text = { hr = 'Policijska uprava je na jugu grada, između bolnice i zračne luke.', en = 'The police station is in the south of town, between the hospital and the airport.' },
        opts = { { t = { hr = 'Postavi GPS do policije.', en = 'Set GPS to the police.' }, act = 'gps', arg = 'police', go = 'thanks' } } },
    thanks = { text = { hr = 'Nema na čemu! Još nešto?', en = 'You are welcome! Anything else?' }, opts = {} },
}

local function merge(nodes)
    for k, v in pairs(CITY) do if not nodes[k] then nodes[k] = v end end
    return nodes
end

local WAY = {   -- answers most people can give
    { t = { hr = 'Što ima zanimljivo u gradu?', en = 'What is there to see in town?' }, go = 'city' },
    { t = { hr = 'Gdje je bolnica?', en = 'Where is the hospital?' }, go = 'hospital' },
    { t = { hr = 'Kako do zračne luke?', en = 'How do I get to the airport?' }, go = 'airport' },
}

OsijekDialogs = {
    -- ---------------------------------------------------------------- people in the street
    citizen = { title = { hr = 'Građanin', en = 'Citizen' }, nodes = merge({
        start = { text = { { hr = 'Bok! Kako ti mogu pomoći?', en = 'Hi! How can I help you?' },
                           { hr = 'Dobar dan! Treba li ti nešto?', en = 'Good day! Do you need something?' },
                           { hr = 'Hej! Nisam te prije vidio ovdje.', en = 'Hey! I have not seen you around here before.' } },
            opts = { WAY[1], WAY[2], WAY[3], WAY[4],
                     { t = { hr = 'Odakle si?', en = 'Where are you from?' }, go = 'from' },
                     { t = { hr = 'Ima li posla u Osijeku?', en = 'Is there any work in Osijek?' }, go = 'job' } } },
        from = { text = { { hr = 'Rođen sam ovdje, u Donjem gradu. Osijek je najbolji!', en = 'I was born here, in the lower town. Osijek is the best!' },
                          { hr = 'Došao sam iz Zagreba zbog posla, ali sad mi je ovo dom.', en = 'I came from Zagreb for work, but now this is home.' } },
            opts = { { t = { hr = 'Kako ti se sviđa ovdje?', en = 'How do you like it here?' }, go = 'like' } } },
        like = { text = { hr = 'Mirno je, ljudi su dobri, a ljeti je Drava puna kupača.', en = 'It is calm, the people are nice, and in summer the Drava is full of swimmers.' }, opts = { WAY[1] } },
        job = { text = { hr = 'Uvijek trebaju ljude u bolnici i na aerodromu. Pitaj tamo!', en = 'They always need people at the hospital and the airport. Ask there!' },
            opts = { WAY[2], WAY[3] } },
    }) },

    -- ---------------------------------------------------------------- hospital
    doctor = { title = { hr = 'Liječnik', en = 'Doctor' }, prefix = { hr = 'Dr.', en = 'Dr.' }, nodes = merge({
        start = { text = { hr = 'Dobar dan, ja sam dr. {name}. Kako vam mogu pomoći?', en = 'Good day, I am Dr. {name}. How can I help you?' },
            opts = { { t = { hr = 'Ozlijeđen sam, možete li me pregledati?', en = 'I am hurt, can you check me?' }, go = 'heal' },
                     { t = { hr = 'Koliko košta liječenje?', en = 'How much is the treatment?' }, go = 'price' },
                     { t = { hr = 'Što ako se onesvijestim u gradu?', en = 'What if I pass out in town?' }, go = 'down' },
                     { t = { hr = 'Radite li noću?', en = 'Do you work at night?' }, go = 'night' } } },
        heal = { text = { hr = 'Sjednite, pogledat ću vas. Pregled i liječenje se plaćaju na licu mjesta.', en = 'Sit down, I will take a look. The treatment is paid on the spot.' },
            opts = { { t = { hr = 'U redu, izliječite me.', en = 'OK, treat me.' }, act = 'heal', go = 'healed' },
                     { t = { hr = 'Ipak ne, hvala.', en = 'No, thank you.' }, go = 'thanks' } } },
        healed = { text = { hr = 'Gotovo! Potpuno ste zdravi. Pazite se na cesti.', en = 'Done! You are completely healthy. Be careful on the road.' }, opts = {} },
        price = { text = { hr = 'Pregled i liječenje koštaju $100. Plaća se s računa ili u gotovini.', en = 'The check and treatment cost $100, from the bank or in cash.' },
            opts = { { t = { hr = 'Želim liječenje.', en = 'I want the treatment.' }, go = 'heal' } } },
        down = { text = { hr = 'Pritisnite G ili upišite /hitna - vozilo hitne dolazi po vas. Ako nitko ne dođe, nakon minute se možete probuditi ovdje.',
                          en = 'Press G or type /hitna - an ambulance comes for you. If nobody comes, after a minute you can wake up here.' }, opts = {} },
        night = { text = { hr = 'Hitna radi 0-24. Mi nikad ne spavamo!', en = 'The ER is open 24/7. We never sleep!' }, opts = {} },
    }) },
    nurse = { title = { hr = 'Medicinska sestra', en = 'Nurse' }, prefix = { hr = 'Sestra', en = 'Nurse' }, nodes = merge({
        start = { text = { hr = 'Dobro došli u hitnu. Ja sam sestra {name}. Što se dogodilo?', en = 'Welcome to the ER. I am nurse {name}. What happened?' },
            opts = { { t = { hr = 'Trebam liječenje.', en = 'I need treatment.' }, go = 'heal' },
                     { t = { hr = 'Gdje je čekaonica?', en = 'Where is the waiting room?' }, go = 'wait' },
                     { t = { hr = 'Tražim nekoga tko je ovdje ležao.', en = 'I am looking for somebody who was here.' }, go = 'patient' } } },
        heal = { text = { hr = 'Doktor će vas odmah pogledati. To je $100.', en = 'The doctor will see you right away. That is $100.' },
            opts = { { t = { hr = 'Plaćam, izvolite.', en = 'Here you go.' }, act = 'heal', go = 'healed' },
                     { t = { hr = 'Ne, hvala.', en = 'No, thanks.' }, go = 'thanks' } } },
        healed = { text = { hr = 'Evo, kao novi ste! Brzo ozdravite.', en = 'There, good as new! Get well soon.' }, opts = {} },
        wait = { text = { hr = 'Stolice su u predvorju i uz prozore. Sjednite, prozvat ćemo vas.', en = 'The chairs are in the lobby and by the windows. Sit down, we will call you.' }, opts = {} },
        patient = { text = { hr = 'Žao mi je, o pacijentima ne smijem davati podatke.', en = 'Sorry, I cannot give out information about patients.' }, opts = {} },
    }) },
    paramedic = { title = { hr = 'Djelatnik hitne', en = 'Paramedic' }, nodes = merge({
        start = { text = { hr = 'Hej. Samo kratka pauza, onda opet na teren.', en = 'Hey. Just a short break, then back out there.' },
            opts = { { t = { hr = 'Kako pozvati hitnu?', en = 'How do I call an ambulance?' }, go = 'call' },
                     { t = { hr = 'Je li težak posao?', en = 'Is it a hard job?' }, go = 'job' }, WAY[1] } },
        call = { text = { hr = 'Nazovi 112 - upiši /hitna ili pritisni G kad si dolje. Dolazimo što brže možemo.', en = 'Call 112 - type /hitna or press G when you are down. We come as fast as we can.' }, opts = {} },
        job = { text = { hr = 'Težak, ali lijep. Svaki spašeni život vrijedi.', en = 'Hard, but good. Every life saved is worth it.' }, opts = {} },
    }) },

    -- ---------------------------------------------------------------- airport
    hostess = { title = { hr = 'Zračna luka Osijek', en = 'Osijek Airport' }, nodes = merge({
        start = { text = { hr = 'Dobro došli u Zračnu luku Osijek! Ja sam {name}, kako vam mogu pomoći?', en = 'Welcome to Osijek Airport! I am {name}, how can I help you?' },
            opts = { { t = { hr = 'Kada je sljedeći let?', en = 'When is the next flight?' }, go = 'flight' },
                     { t = { hr = 'Gdje je preuzimanje prtljage?', en = 'Where is the baggage claim?' }, go = 'bags' },
                     { t = { hr = 'Mogu li kupiti kartu?', en = 'Can I buy a ticket?' }, go = 'ticket' },
                     { t = { hr = 'Gdje je izlaz za grad?', en = 'Where is the way to town?' }, go = 'exit' } } },
        flight = { text = { hr = 'Sljedeći let za {flight} polijeće u {time}, izlaz {gate}. Prijava je na ovim šalterima.', en = 'The next flight to {flight} leaves at {time}, gate {gate}. Check-in is at these desks.' },
            opts = { { t = { hr = 'Ima li još letova?', en = 'Any other flights?' }, go = 'flight' } } },
        bags = { text = { hr = 'Trake za prtljagu su na zapadnom kraju terminala, lijevo kad uđete.', en = 'The baggage belts are at the west end of the terminal, left when you come in.' }, opts = {} },
        ticket = { text = { hr = 'Trenutno imamo samo dolazne letove iz Los Santosa. Prodaja karata uskoro!', en = 'Right now we only have arrivals from Los Santos. Tickets on sale soon!' }, opts = {} },
        exit = { text = { hr = 'Glavni izlaz je na sjevernoj strani, kroz klizna vrata. Cesta vodi ravno u grad.', en = 'The main exit is on the north side, through the sliding doors. The road leads straight to town.' },
            opts = { WAY[1] } },
    }) },
    security = { title = { hr = 'Zaštitar', en = 'Security' }, prefix = { hr = 'Zaštitar', en = 'Guard' }, nodes = merge({
        start = { text = { hr = 'Dobar dan. Molim vas, imate li osobnu iskaznicu?', en = 'Good day. Do you have your ID, please?' },
            opts = { { t = { hr = 'Izvolite.', en = 'Here you go.' }, act = 'id', go = 'ok' },
                     { t = { hr = 'Što je zabranjeno unijeti?', en = 'What is not allowed inside?' }, go = 'rules' },
                     { t = { hr = 'Zašto me pitate?', en = 'Why are you asking?' }, go = 'why' } } },
        ok = { text = { hr = 'Hvala, sve je u redu. Sretan put!', en = 'Thank you, all good. Have a nice trip!' }, opts = {} },
        rules = { text = { hr = 'Oružje, eksplozivi i tekućine preko 100 ml. Sve ostalo je u redu.', en = 'Weapons, explosives and liquids over 100 ml. Everything else is fine.' }, opts = {} },
        why = { text = { hr = 'Rutinska provjera, gospodine. Molim vas za suradnju.', en = 'Routine check, sir. Please cooperate.' },
            opts = { { t = { hr = 'Dobro, izvolite osobnu.', en = 'OK, here is my ID.' }, act = 'id', go = 'ok' } } },
    }) },
    pilot = { title = { hr = 'Pilot', en = 'Pilot' }, prefix = { hr = 'Kapetan', en = 'Captain' }, nodes = merge({
        start = { text = { hr = 'Pozdrav! Upravo sam sletio iz Los Santosa.', en = 'Hello! I just landed from Los Santos.' },
            opts = { { t = { hr = 'Kakav je bio let?', en = 'How was the flight?' }, go = 'flight' },
                     { t = { hr = 'Kako postati pilot?', en = 'How do I become a pilot?' }, go = 'become' }, WAY[1] } },
        flight = { text = { hr = 'Malo turbulencija iznad mora, ali pogled na Osijek pri slijetanju je predivan.', en = 'A bit of turbulence over the sea, but the view of Osijek on landing is beautiful.' }, opts = {} },
        become = { text = { hr = 'Puno učenja i sati letenja. Ali vrijedi svake minute!', en = 'A lot of study and flight hours. But worth every minute!' }, opts = {} },
    }) },
    traveler = { title = { hr = 'Putnik', en = 'Traveller' }, nodes = merge({
        start = { text = { { hr = 'Čekam let, već sat vremena... A ti?', en = 'Waiting for my flight, for an hour already... You?' },
                           { hr = 'Upravo sam stigao! Prvi put sam u Osijeku.', en = 'I just arrived! First time in Osijek.' } },
            opts = { { t = { hr = 'Kamo putuješ?', en = 'Where are you going?' }, go = 'where' },
                     { t = { hr = 'Dobro došao u Osijek!', en = 'Welcome to Osijek!' }, go = 'welcome' }, WAY[1] } },
        where = { text = { hr = 'U Los Santos, posjetiti obitelj. Nadam se da let neće kasniti.', en = 'To Los Santos, to visit family. I hope the flight is not late.' }, opts = {} },
        welcome = { text = { hr = 'Hvala! Što mi preporučuješ vidjeti?', en = 'Thanks! What should I see?' }, opts = { WAY[1] } },
    }) },

    -- ---------------------------------------------------------------- police station (PU Osijek)
    police = { title = { hr = 'Policija', en = 'Police' }, prefix = { hr = 'Policajac', en = 'Officer' }, nodes = merge({
        start = { text = { hr = 'Dobar dan! Kako vam mogu pomoći, građanine?', en = 'Hello! How can I help you at the moment, citizen?' },
            opts = { { t = { hr = 'Želim prijaviti kazneno djelo.', en = 'I need to file a police report.' }, go = 'report' },
                     { t = { hr = 'Trebam dozvolu za oružje, kako je dobiti?', en = 'I need a gun licence, how can I get one?' }, go = 'gun' },
                     { t = { hr = 'Moram platiti kaznu.', en = 'I need to pay a fine.' }, go = 'fine' },
                     { t = { hr = 'Želim se zaposliti u policiji.', en = 'I want to join the police.' }, go = 'job' },
                     { t = { hr = 'Izgubio sam osobnu iskaznicu.', en = 'I lost my ID card.' }, go = 'lostid' } } },
        report = { text = { hr = 'Razumijem. Što se dogodilo?', en = 'I understand. What happened?' },
            opts = { { t = { hr = 'Ukradeno mi je vozilo.', en = 'My car was stolen.' }, go = 'reported' },
                     { t = { hr = 'Netko me napao.', en = 'Somebody attacked me.' }, go = 'reported' },
                     { t = { hr = 'Opljačkali su me / ukrali novčanik.', en = 'I was robbed / my wallet was stolen.' }, go = 'reported' },
                     { t = { hr = 'Vidio sam prometnu nesreću.', en = 'I saw a traffic accident.' }, go = 'accident' } } },
        reported = { text = { hr = 'Zapisao sam prijavu pod brojem {case}. Naši policajci će provjeriti i javiti vam se.', en = 'I wrote the report down, number {case}. Our officers will check it and contact you.' },
            opts = { { t = { hr = 'Hvala vam.', en = 'Thank you.' }, go = 'thanks' } } },
        accident = { text = { hr = 'Hvala na dojavi. Ako ima ozlijeđenih, odmah zovite 112 (/hitna).', en = 'Thanks for telling us. If somebody is hurt, call 112 (/hitna) right away.' }, opts = {} },
        gun = { text = { hr = 'Trebate biti punoljetni, bez kaznenog dosjea i proći tečaj rukovanja oružjem. Zahtjev predajete ovdje na šalteru.',
                         en = 'You must be an adult, have no criminal record and pass a weapons course. You hand in the request here at the desk.' },
            opts = { { t = { hr = 'Koliko to traje?', en = 'How long does it take?' }, go = 'gun2' } } },
        gun2 = { text = { hr = 'Obično tjedan dana. Javit ćemo vam kad je dozvola gotova.', en = 'Usually a week. We will call you when the licence is ready.' }, opts = {} },
        fine = { text = { hr = 'Kaznu možete platiti ovdje ili u banci. Imate li broj prekršajnog naloga?', en = 'You can pay the fine here or at the bank. Do you have the ticket number?' },
            opts = { { t = { hr = 'Nemam ga kod sebe.', en = 'I do not have it with me.' }, go = 'fine2' } } },
        fine2 = { text = { hr = 'Onda dođite kad ga nađete. Kazna se mora platiti u roku od 8 dana.', en = 'Then come back when you find it. The fine must be paid within 8 days.' }, opts = {} },
        job = { text = { hr = 'Odlično! Javite se upravi servera za prijem. Uniformu dobivate u svlačionici iza šaltera.', en = 'Great! Talk to the server staff to join. You get your uniform in the locker room behind the desk.' }, opts = {} },
        lostid = { text = { hr = 'Novu osobnu možete dobiti pri izradi lika ili kod službenika. Pazite gdje je ostavljate!', en = 'You can get a new ID from the clerk. Be careful where you leave it!' }, opts = {} },
    }) },

    -- ---------------------------------------------------------------- gun shop (Oružarnica) + road workers
    gunshop = { title = { hr = 'Oružarnica', en = 'Gun shop' }, nodes = merge({
        start = { text = { hr = 'Dobro došli u Oružarnicu! Lov, sport i samoobrana. Što vas zanima?', en = 'Welcome to the gun shop! Hunting, sport and self defence. What are you looking for?' },
            opts = { { t = { hr = 'Pištolj ($750)', en = 'Pistol ($750)' }, act = 'gun', arg = 'pistol', go = 'bought' },
                     { t = { hr = 'Municija za pištolj ($60)', en = 'Pistol ammo ($60)' }, act = 'gun', arg = 'ammo', go = 'bought' },
                     { t = { hr = 'Nož ($120)', en = 'Knife ($120)' }, act = 'gun', arg = 'knife', go = 'bought' },
                     { t = { hr = 'Palica ($80)', en = 'Bat ($80)' }, act = 'gun', arg = 'bat', go = 'bought' },
                     { t = { hr = 'Svjetiljka ($40)', en = 'Flashlight ($40)' }, act = 'gun', arg = 'flashlight', go = 'bought' },
                     { t = { hr = 'Trebam li dozvolu?', en = 'Do I need a licence?' }, go = 'licence' } } },
        bought = { text = { hr = 'Izvolite. Pažljivo s tim, i čuvajte račun!', en = 'Here you go. Be careful with it, and keep the receipt!' }, opts = {} },
        licence = { text = { hr = 'Za vatreno oružje vam treba dozvola iz policijske uprave. Hladno oružje možete kupiti odmah.', en = 'For firearms you need a licence from the police station. Melee weapons you can buy right away.' },
            opts = { { t = { hr = 'Gdje je policija?', en = 'Where is the police?' }, go = 'policegps' } } },
    }) },
    -- ---------------------------------------------------------------- v1.0.36 shops: STIL (clothes) + VOLT (electronics)
    clothes = { title = { hr = 'STIL - Odjeća', en = 'STIL - Clothes' }, nodes = merge({
        start = { text = { { hr = 'Dobro došli u STIL! Nova kolekcija je stigla. Želite li se presvući?', en = 'Welcome to STIL! The new collection is in. Would you like to try something on?' },
                           { hr = 'Bok! Kabine su lijevo, ogledalo desno. Mogu li pomoći?', en = 'Hi! Changing rooms are on the left, mirror on the right. Can I help?' } },
            opts = { { t = { hr = 'Želim promijeniti odjeću', en = 'I want to change my clothes' }, act = 'clothes', go = 'start' },
                     { t = { hr = 'Imate li popust?', en = 'Any discounts?' }, go = 'sale' } } },
        sale = { text = { hr = 'Ovaj tjedan -30% na jakne! Pogledajte plakat vani.', en = '30% off jackets this week! Check the billboard outside.' },
            opts = { { t = { hr = 'Super, idem probati', en = 'Great, let me try' }, act = 'clothes', go = 'start' } } },
    }) },
    tech = { title = { hr = 'VOLT - Elektronika', en = 'VOLT - Electronics' }, nodes = merge({
        start = { text = { { hr = 'Dobro došli u VOLT! Mobiteli, radio stanice, tableti... što trebate?', en = 'Welcome to VOLT! Phones, radios, tablets... what do you need?' },
                           { hr = 'Bok! Imamo nove mobitele na akciji.', en = 'Hi! New phones are on sale.' } },
            opts = { { t = { hr = 'Pokaži mi ponudu', en = 'Show me what you have' }, act = 'tech', go = 'start' },
                     { t = { hr = 'Čemu služi radio?', en = 'What is the radio for?' }, go = 'radio' } } },
        radio = { text = { hr = 'Radio stanicu koriste policija, hitna i ekipe za dogovor. Uz radio dobivate i kanal.', en = 'Police, EMS and crews use radios to talk. You get a channel with it.' },
            opts = { { t = { hr = 'Pokaži mi ponudu', en = 'Show me what you have' }, act = 'tech', go = 'start' } } },
    }) },
    worker = { title = { hr = 'Radnik na cesti', en = 'Road worker' }, nodes = merge({
        start = { text = { { hr = 'Pazi, ovdje se radi! Ne prilazi rupi.', en = 'Careful, work in progress! Stay away from the hole.' },
                           { hr = 'Bok. Mijenjamo cijevi, cesta je djelomično zatvorena.', en = 'Hi. We are changing the pipes, the road is partly closed.' } },
            opts = { { t = { hr = 'Koliko dugo traju radovi?', en = 'How long will the works take?' }, go = 'long' },
                     { t = { hr = 'Treba li vam pomoć?', en = 'Do you need help?' }, go = 'help' }, WAY[1] } },
        long = { text = { hr = 'Još dva tjedna, ako ne bude kiše. Kao i uvijek!', en = 'Two more weeks if it does not rain. As always!' }, opts = {} },
        help = { text = { hr = 'Hvala, ali bez kacige ne smiješ ovdje. Pitaj u gradu za posao.', en = 'Thanks, but without a helmet you cannot be here. Ask in town for a job.' }, opts = {} },
    }) },

    -- ---------------------------------------------------------------- beach
    lifeguard = { title = { hr = 'Spasilac', en = 'Lifeguard' }, nodes = merge({
        start = { text = { hr = 'Bok! Pazim na kupače. Treba li ti nešto?', en = 'Hi! I am watching the swimmers. Need something?' },
            opts = { { t = { hr = 'Je li sigurno skakati s tornja?', en = 'Is it safe to jump from the tower?' }, go = 'tower' },
                     { t = { hr = 'Koliko je duboka Drava?', en = 'How deep is the Drava?' }, go = 'deep' },
                     { t = { hr = 'Mogu li uzeti jet ski?', en = 'Can I take a jet ski?' }, go = 'jetski' } } },
        tower = { text = { hr = 'S 3 metra je za početnike, 5 metara samo za hrabre. Skači samo na kraju mola gdje je duboko!', en = '3 metres is for beginners, 5 metres only for the brave. Jump only at the end of the pier where it is deep!' }, opts = {} },
        deep = { text = { hr = 'Oko 12 metara na sredini. Na dnu ima i jedna stara olupina broda.', en = 'About 12 metres in the middle. There is even an old wreck on the bottom.' },
            opts = { { t = { hr = 'Gdje je olupina?', en = 'Where is the wreck?' }, go = 'wreck' } } },
        jetski = { text = { hr = 'Jet skiji su uz mol, priđi i pritisni F. Vozi polako blizu kupača!', en = 'The jet skis are at the pier, walk up and press F. Go slow near swimmers!' }, opts = {} },
    }) },
    bartender = { title = { hr = 'Beach bar', en = 'Beach bar' }, nodes = merge({
        start = { text = { hr = 'Bok! Što ćeš popiti?', en = 'Hi! What can I get you?' },
            opts = { { t = { hr = 'Limunadu ($5)', en = 'A lemonade ($5)' }, act = 'buy', arg = 'limunada', go = 'served' },
                     { t = { hr = 'Hladno pivo ($6)', en = 'A cold beer ($6)' }, act = 'buy', arg = 'pivo', go = 'served' },
                     { t = { hr = 'Kavu ($3)', en = 'A coffee ($3)' }, act = 'buy', arg = 'kava', go = 'served' },
                     { t = { hr = 'Sok ($4)', en = 'A juice ($4)' }, act = 'buy', arg = 'sok', go = 'served' },
                     { t = { hr = 'Do kada radite?', en = 'How late are you open?' }, go = 'open' } } },
        served = { text = { hr = 'Izvoli, uživaj! Još nešto?', en = 'Here you go, enjoy! Anything else?' }, opts = {} },
        open = { text = { hr = 'Dok ima sunca i kupača!', en = 'As long as there is sun and swimmers!' }, opts = {} },
    }) },
}

-- which dialog a ped gets (by model)
OsijekDialogRoles = {
    s_m_m_doctor_01 = 'doctor', s_f_y_scrubs_01 = 'nurse', s_m_m_paramedic_01 = 'paramedic',
    s_f_y_airhostess_01 = 'hostess', s_m_m_security_01 = 'security', s_m_m_pilot_01 = 'pilot',
    s_m_y_cop_01 = 'police', s_f_y_cop_01 = 'police', s_m_y_ammucity_01 = 'gunshop', s_f_m_shop_high = 'clothes', s_m_m_lifeinvad_01 = 'tech',
    s_m_y_construct_01 = 'worker', s_m_y_construct_02 = 'worker',
    s_m_y_baywatch_01 = 'lifeguard', s_f_y_baywatch_01 = 'lifeguard', s_f_y_beachbarstaff_01 = 'bartender',
}

OsijekDialogNames = {
    m = { 'Marko', 'Ivan', 'Luka', 'Josip', 'Petar', 'Tomislav', 'Matej', 'Ante', 'Filip', 'Dario', 'Krešimir', 'Domagoj' },
    f = { 'Ana', 'Ivana', 'Marija', 'Petra', 'Lucija', 'Maja', 'Katarina', 'Ema', 'Sara', 'Martina', 'Nikolina', 'Tea' },
    last = { 'Horvat', 'Kovačević', 'Babić', 'Marić', 'Jurić', 'Novak', 'Knežević', 'Vuković', 'Matić', 'Pavlović' },
}
OsijekDialogFlights = { 'Los Santos', 'Zagreb', 'Beč', 'Frankfurt', 'London', 'Liberty City' }

-- v1.0.29: café in the airport terminal (same drinks as the beach bar)
OsijekDialogs.cafe = { title = { hr = 'Kafić', en = 'Café' }, nodes = OsijekDialogs.bartender.nodes }
OsijekDialogRoles.s_f_y_shop_mid = 'cafe'
