#!/usr/bin/env ruby -wKU

# Supported languages:
# ar,ca,cs,da,de,el,en,en-GB,es,fi,fr,he,hr,hu,id,it,ja,ko,ms,nb,nl,pl,pt,pt-PT,ro,ru,sk,sv,th,tr,uk,vi,zh-Hans,zh-Hant
# * Arabic
# * Catalan
# * Czech
# * Danish
# * German
# * Greek
# * English
# * English (UK)
# * Spanish
# * Finnish
# * French
# * Hebrew
# * Croatian
# * Hungarian
# * Indonesian
# * Italian
# * Japanese
# * Korean
# * Malay
# * Norwegian (Bokmål)
# * Dutch
# * Polish
# * Portuguese
# * Portuguese (Portugal)
# * Romanian
# * Russian
# * Slovak
# * Swedish
# * Thai
# * Turkish
# * Ukranian
# * Vietnamese
# * Chinese (China) [zh-Hans]
# * Chinese (Taiwan) [zh-Hant]

LANGS={
  'de' => 'de', # German
  'es' => 'es', # Spanish
  'fr' => 'fr', # French
  'he' => 'he', # Hebrew
  'hr' => 'hr', # Croatian
  'hu' => 'hu', # Hungarian
  'id' => 'id', # Indonesian
  'it' => 'it', # Italian
  'ja' => 'ja', # Japanese
  'nb' => 'nb', # Norwegian (Bokmål)
  'nl' => 'nl', # Dutch
  'pl' => 'pl', # Polish
  'pt' => 'pt', # Portuguese
  'sv' => 'sv', # Swedish
  'tr' => 'tr', # Turkish
  'zh-cn' => 'zh-Hans', # Chinese (Chine)
  'zh-tw' => 'zh-Hant' # Chinese (Taiwan)
}

LANGS.each do |code,local|
  puts "Updating #{code}"
  system "cp #{local}.lproj/Localizable.strings #{local}.lproj/Localizable.strings.bak"
  system "curl -so #{local}.lproj/Localizable.strings http://translate.wordpress.org/projects/ios/dev/#{code}/default/export-translations?format=strings" or begin
    puts "Error downloading #{code}"
  end
  system "php fix-translation.php #{local}.lproj/Localizable.strings"
  system "plutil -lint #{local}.lproj/Localizable.strings" and system "rm #{local}.lproj/Localizable.strings.bak"
  system "grep -aP '\\x00\\x22\\x00\\x22' #{local}.lproj/Localizable.strings"
end