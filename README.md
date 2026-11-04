# Shpping

Minimalistische focus-app voor macOS, gebouwd voor werken met ADD: één taak tegelijk, tijd als lijn in plaats van cijfers, en een plek om afleidende gedachten kwijt te kunnen.

## Wat het doet

- **Dagstart**: opent één keer per dag (vanaf 5:00). Je zet je taken voor vandaag erin; wat gisteren niet af is kun je meenemen of laten vallen.
- **Focus starten** (`⌃⌥F` of het doosje in de menubalk): vink één of meer taken uit je daglijst aan (1–9) en een duur (25/45/60/90, standaard je laatste keuze), dan ↩.
- **Focusbalk**: dunne balk bovenin het scherm met je huidige taak (bijv. 2/3), de resterende minuten en een lijn die korter wordt. Klikken gaan er dwars doorheen.
- **Taak afvinken** (`⌃⌥D`): huidige taak af, de balk springt naar de volgende. Laatste taak af = sessie klaar.
- **Gedachte parkeren** (`⌃⌥Spatie`): typ, ↩, weg. Na de sessie kies je per gedachte: vandaag / later / weg.
- **Einde sessie**: afvinken, nog 10 minuten, of nog niet af. Plus één zachte beweeg-suggestie.
- **Notificaties uit**: Shpping draait bij start/einde de opdrachten `Shpping focus aan` en `Shpping focus uit` (zelf aanmaken in Opdrachten, zie het menu → *Notificaties uitzetten instellen…*).

## Bouwen

```sh
./scripts/build.sh --open   # bouwt, installeert in ~/Applications en start
```

Vereist alleen de Command Line Tools (Swift 6), geen Xcode.

## Data

`~/Library/Application Support/Shpping/data.json`, lokaal. Een lopende sessie wordt hervat als de app herstart.
