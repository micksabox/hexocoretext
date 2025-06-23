# Merkle Tree Implementation Plan for Word Validation

## Overview
This document outlines the implementation plan for client-side word validation using merkle trees in the Hexocoretext game. The solution uses `@scrabble-solver/word-lists` for word lists and `@ericnordelo/strk-merkle-tree` for merkle proof generation, optimized for browser performance.

## Performance Analysis

### Memory Constraints
- **Word List Size**: ~100,000 words × 8 chars average = 800KB raw text
- **Merkle Tree Overhead**: 2-3x raw data = ~2-2.5MB
- **Total Memory**: ~3-4MB per locale
- **Browser Limits**: 
  - Desktop: 1-4GB (sufficient)
  - Mobile: 256MB-1GB (manageable)

### Performance Metrics
- **Tree Construction**: ~500-1000ms on modern devices
- **Proof Generation**: ~10-50ms per word
- **Word Validation**: O(1) using Set lookup

## Implementation Architecture

### 1. Package Dependencies
```json
{
  "dependencies": {
    "@scrabble-solver/word-lists": "^latest",
    "@ericnordelo/strk-merkle-tree": "^latest"
  }
}
```

### 2. Type Definitions

#### `/client/src/types/wordList.ts`
```typescript
export enum Locale {
  EN_US = 'en-US',
  EN_GB = 'en-GB',
  // Other locales disabled initially
}

export interface WordListState {
  locale: Locale;
  words: Set<string>; // For O(1) lookup
  merkleTree: StandardMerkleTree | null;
  merkleRoot: string | null;
  isLoading: boolean;
  error: string | null;
}

export interface WordValidationResult {
  isValid: boolean;
  proof?: string[];
  normalizedWord: string;
}
```

### 3. Core Utilities

#### `/client/src/utils/wordList.ts`
```typescript
import { getWordList, Locale as ScrabbleLocale } from '@scrabble-solver/word-lists';

/**
 * Normalize a word for consistent comparison
 * - Convert to uppercase
 * - Remove diacritics (é → e)
 */
export function normalizeWord(word: string): string {
  return word
    .toUpperCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, ""); // Remove diacritics
}

/**
 * Load word list from scrabble-solver package
 */
export async function loadWordList(locale: Locale): Promise<string[]> {
  // Map our locale enum to scrabble-solver locale
  const scrabbleLocale = locale as unknown as ScrabbleLocale;
  const words = await getWordList(scrabbleLocale);
  
  // Normalize all words
  return words.map(normalizeWord);
}

/**
 * Convert word list to Set for efficient lookups
 */
export function createWordSet(words: string[]): Set<string> {
  return new Set(words);
}
```

#### `/client/src/utils/merkleTree.ts`
```typescript
import { StandardMerkleTree } from '@ericnordelo/strk-merkle-tree';

/**
 * Build merkle tree from word list
 */
export function buildMerkleTree(words: string[]): StandardMerkleTree {
  // Format words as single-element arrays for StandardMerkleTree
  const values = words.map(word => [word]);
  
  // Create tree with string type
  return StandardMerkleTree.of(values, ['string']);
}

/**
 * Generate merkle proof for a word
 */
export function generateProof(
  tree: StandardMerkleTree, 
  word: string
): string[] | null {
  // Find the word in the tree
  for (const [i, v] of tree.entries()) {
    if (v[0] === word) {
      return tree.getProof(i);
    }
  }
  return null;
}

/**
 * Get merkle root from tree
 */
export function getMerkleRoot(tree: StandardMerkleTree): string {
  return tree.root;
}
```

### 4. React Hook

#### `/client/src/hooks/useWordValidation.ts`
```typescript
import { useState, useCallback, useEffect } from 'react';
import { Locale, WordListState, WordValidationResult } from '../types/wordList';
import { loadWordList, normalizeWord, createWordSet } from '../utils/wordList';
import { buildMerkleTree, generateProof, getMerkleRoot } from '../utils/merkleTree';

export function useWordValidation() {
  const [wordListState, setWordListState] = useState<WordListState>({
    locale: Locale.EN_US,
    words: new Set(),
    merkleTree: null,
    merkleRoot: null,
    isLoading: false,
    error: null,
  });

  // Load word list for specified locale
  const loadLocale = useCallback(async (locale: Locale) => {
    setWordListState(prev => ({ ...prev, isLoading: true, error: null }));
    
    try {
      // Load words from package
      const words = await loadWordList(locale);
      
      // Create Set for fast lookups
      const wordSet = createWordSet(words);
      
      // Build merkle tree (consider Web Worker for this)
      const merkleTree = buildMerkleTree(words);
      const merkleRoot = getMerkleRoot(merkleTree);
      
      setWordListState({
        locale,
        words: wordSet,
        merkleTree,
        merkleRoot,
        isLoading: false,
        error: null,
      });
    } catch (error) {
      setWordListState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Failed to load word list',
      }));
    }
  }, []);

  // Validate a word and generate proof
  const validateWord = useCallback(async (word: string): Promise<WordValidationResult> => {
    const normalizedWord = normalizeWord(word);
    
    // Quick check using Set
    const isValid = wordListState.words.has(normalizedWord);
    
    if (!isValid || !wordListState.merkleTree) {
      return { isValid: false, normalizedWord };
    }
    
    // Generate proof only if word is valid
    const proof = generateProof(wordListState.merkleTree, normalizedWord);
    
    return {
      isValid: true,
      proof: proof || undefined,
      normalizedWord,
    };
  }, [wordListState]);

  // Load default locale on mount
  useEffect(() => {
    loadLocale(Locale.EN_US);
  }, [loadLocale]);

  return {
    wordListState,
    validateWord,
    loadLocale,
    getMerkleRoot: () => wordListState.merkleRoot,
  };
}
```

### 5. UI Components

#### `/client/src/components/LocaleSelector.tsx`
```typescript
import React from 'react';
import { Locale } from '../types/wordList';

interface LocaleSelectorProps {
  currentLocale: Locale;
  onLocaleChange: (locale: Locale) => void;
  isLoading: boolean;
}

export function LocaleSelector({ currentLocale, onLocaleChange, isLoading }: LocaleSelectorProps) {
  return (
    <div className="locale-selector">
      <label htmlFor="locale">Language:</label>
      <select 
        id="locale"
        value={currentLocale}
        onChange={(e) => onLocaleChange(e.target.value as Locale)}
        disabled={isLoading}
      >
        <option value={Locale.EN_US}>English (US)</option>
        <option value={Locale.EN_GB} disabled>English (GB) - Coming Soon</option>
      </select>
      {isLoading && <span className="loading-indicator">Loading word list...</span>}
    </div>
  );
}
```

### 6. Integration with Game Actions

Update the game actions component to include:
- A "Check Word" button that appears when the player selects tiles
- Display validation results (valid/invalid)
- Store the merkle proof for submission with the turn
- Show the locale selector in the game UI

## Performance Optimizations

### 1. Web Worker for Tree Construction
Create a Web Worker to build the merkle tree without blocking the UI:

```typescript
// /client/src/workers/merkleTreeWorker.ts
self.addEventListener('message', (event) => {
  const { words } = event.data;
  const tree = buildMerkleTree(words);
  self.postMessage({ tree: tree.dump() });
});
```

### 2. IndexedDB Caching
Cache constructed merkle trees to avoid rebuilding on page refresh:

```typescript
async function getCachedTree(locale: Locale): Promise<StandardMerkleTree | null> {
  // Implementation using IndexedDB
}

async function cacheTree(locale: Locale, tree: StandardMerkleTree): Promise<void> {
  // Implementation using IndexedDB
}
```

### 3. Progressive Loading
Load word lists on-demand and show progress:
- Initial load: Common words (top 10,000)
- Background load: Complete word list
- Update UI to show loading progress

## User Experience

### Word Validation Flow
1. Player selects tiles to form a word
2. "Check Word" button becomes visible
3. Player clicks "Check Word" (explicit user action as requested)
4. System validates word and shows result:
   - ✅ Valid: "EXAMPLE is a valid word!"
   - ❌ Invalid: "EXAMPL is not a valid word"
5. If valid, merkle proof is stored for turn submission

### Error Handling
- Network errors: "Failed to load word list. Please refresh."
- Validation errors: Clear messages about why validation failed
- Loading states: Show progress indicators during long operations

## Implementation Checklist

- [ ] Install required npm packages
- [ ] Create type definitions
- [ ] Implement word list utilities
- [ ] Implement merkle tree utilities
- [ ] Create useWordValidation hook
- [ ] Build LocaleSelector component
- [ ] Add Web Worker for tree construction
- [ ] Implement IndexedDB caching
- [ ] Integrate with game actions
- [ ] Add comprehensive error handling
- [ ] Test on mobile devices
- [ ] Optimize bundle size

## Notes

- The merkle proof format must match what the Cairo contract expects
- Word normalization must be consistent between client and contract
- Consider lazy loading for better initial page load
- Monitor memory usage on low-end devices
- Add analytics to track validation performance