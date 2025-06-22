use core::poseidon::poseidon_hash_span;

// Simple word validator for now
// In a real implementation, this would use a Merkle tree
#[derive(Drop)]
pub struct WordValidator {
    pub merkle_root: felt252,
}

#[generate_trait]
pub impl WordValidatorImpl of WordValidatorTrait {
    fn new(merkle_root: felt252) -> WordValidator {
        WordValidator { merkle_root }
    }

    // Validate a word against the dictionary
    // For now, this is a placeholder that accepts words of length >= 3
    fn is_valid_word(self: @WordValidator, word: @ByteArray) -> bool {
        // TODO: Implement proper Merkle proof validation
        // For testing, accept any word with length >= 3
        word.len() >= 3
    }

    // Convert array of letters to a word
    fn letters_to_word(letters: @Array<felt252>) -> ByteArray {
        let mut word = "";
        let mut i = 0;
        while i < letters.len() {
            let letter = *letters.at(i);
            // Convert felt252 letter to string
            if letter == 'A' { word.append_byte('A'); }
            else if letter == 'B' { word.append_byte('B'); }
            else if letter == 'C' { word.append_byte('C'); }
            else if letter == 'D' { word.append_byte('D'); }
            else if letter == 'E' { word.append_byte('E'); }
            else if letter == 'F' { word.append_byte('F'); }
            else if letter == 'G' { word.append_byte('G'); }
            else if letter == 'H' { word.append_byte('H'); }
            else if letter == 'I' { word.append_byte('I'); }
            else if letter == 'J' { word.append_byte('J'); }
            else if letter == 'K' { word.append_byte('K'); }
            else if letter == 'L' { word.append_byte('L'); }
            else if letter == 'M' { word.append_byte('M'); }
            else if letter == 'N' { word.append_byte('N'); }
            else if letter == 'O' { word.append_byte('O'); }
            else if letter == 'P' { word.append_byte('P'); }
            else if letter == 'Q' { word.append_byte('Q'); }
            else if letter == 'R' { word.append_byte('R'); }
            else if letter == 'S' { word.append_byte('S'); }
            else if letter == 'T' { word.append_byte('T'); }
            else if letter == 'U' { word.append_byte('U'); }
            else if letter == 'V' { word.append_byte('V'); }
            else if letter == 'W' { word.append_byte('W'); }
            else if letter == 'X' { word.append_byte('X'); }
            else if letter == 'Y' { word.append_byte('Y'); }
            else if letter == 'Z' { word.append_byte('Z'); }
            else { word.append_byte('?'); }
            i += 1;
        };
        word
    }

    // Calculate hash of a word for Merkle tree
    fn hash_word(word: @ByteArray) -> felt252 {
        let mut data = array![];
        let mut i = 0;
        while i < word.len() {
            data.append(word[i].into());
            i += 1;
        };
        poseidon_hash_span(data.span())
    }
}

#[cfg(test)]
mod tests {
    use super::{WordValidatorTrait};

    #[test]
    fn test_is_valid_word() {
        let validator = WordValidatorTrait::new(0);
        
        assert(!validator.is_valid_word(@"AB"), 'Two letter word invalid');
        assert(validator.is_valid_word(@"ABC"), 'Three letter word valid');
        assert(validator.is_valid_word(@"HELLO"), 'Five letter word valid');
    }

    #[test]
    fn test_letters_to_word() {
        let letters = array!['H', 'E', 'L', 'L', 'O'];
        let word = WordValidatorTrait::letters_to_word(@letters);
        assert(word == "HELLO", 'Should convert to HELLO');
        
        let short_letters = array!['C', 'A', 'T'];
        let short_word = WordValidatorTrait::letters_to_word(@short_letters);
        assert(short_word == "CAT", 'Should convert to CAT');
    }

    #[test]
    fn test_hash_word() {
        let word1 = "HELLO";
        let word2 = "WORLD";
        
        let hash1 = WordValidatorTrait::hash_word(@word1);
        let hash2 = WordValidatorTrait::hash_word(@word2);
        
        // Different words should have different hashes
        assert(hash1 != hash2, 'Different words, different hash');
        
        // Same word should have same hash
        let hash1_again = WordValidatorTrait::hash_word(@word1);
        assert(hash1 == hash1_again, 'Same word, same hash');
    }
}