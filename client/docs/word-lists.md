npm i --save @scrabble-solver/word-lists

use the function `getWordList` passing in a locale from this list:

```ts
export enum Locale {
  DE_DE = 'de-DE',
  EN_GB = 'en-GB',
  EN_US = 'en-US',
  ES_ES = 'es-ES',
  FA_IR = 'fa-IR',
  FR_FR = 'fr-FR',
  PL_PL = 'pl-PL',
  RO_RO = 'ro-RO',
  TR_TR = 'tr-TR',
}
```

An array of strings is returned.