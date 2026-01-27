#!/usr/bin/env runhaskell
{-# LANGUAGE OverloadedStrings #-}
-- Haskell BCS E2E Test Runner

import Data.Word
import Data.Int
import Data.Bits
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (digitToInt, intToDigit)
import Control.Monad (replicateM)
import Numeric (showHex)

-- Simple BCS Serializer
newtype Serializer = Serializer { getBytes :: [Word8] }

emptySerializer :: Serializer
emptySerializer = Serializer []

writeBool :: Bool -> Serializer -> Serializer
writeBool b (Serializer bs) = Serializer (bs ++ [if b then 1 else 0])

writeU8 :: Word8 -> Serializer -> Serializer
writeU8 v (Serializer bs) = Serializer (bs ++ [v])

writeU16 :: Word16 -> Serializer -> Serializer
writeU16 v s = writeU8 (fromIntegral (v .&. 0xFF)) $ writeU8 (fromIntegral ((v `shiftR` 8) .&. 0xFF)) s

writeU32 :: Word32 -> Serializer -> Serializer
writeU32 v s = foldr (\i acc -> writeU8 (fromIntegral ((v `shiftR` (i * 8)) .&. 0xFF)) acc) s [0..3]

writeU64 :: Word64 -> Serializer -> Serializer
writeU64 v s = foldr (\i acc -> writeU8 (fromIntegral ((v `shiftR` (i * 8)) .&. 0xFF)) acc) s [0..7]

writeU128 :: [Word8] -> Serializer -> Serializer
writeU128 bytes (Serializer bs) = Serializer (bs ++ bytes)

writeI8 :: Int8 -> Serializer -> Serializer
writeI8 v = writeU8 (fromIntegral v)

writeI16 :: Int16 -> Serializer -> Serializer
writeI16 v = writeU16 (fromIntegral v)

writeI32 :: Int32 -> Serializer -> Serializer
writeI32 v = writeU32 (fromIntegral v)

writeI64 :: Int64 -> Serializer -> Serializer
writeI64 v = writeU64 (fromIntegral v)

writeI128 :: [Word8] -> Serializer -> Serializer
writeI128 = writeU128

writeUleb128 :: Word32 -> Serializer -> Serializer
writeUleb128 v s
  | v < 0x80 = writeU8 (fromIntegral v) s
  | otherwise = writeU8 (fromIntegral ((v .&. 0x7F) .|. 0x80)) $ writeUleb128 (v `shiftR` 7) s

writeString :: String -> Serializer -> Serializer
writeString str s = 
  let bytes = C8.unpack (C8.pack str)
      len = length bytes
  in foldr (writeU8 . fromIntegral . fromEnum) (writeUleb128 (fromIntegral len) s) (reverse bytes)

writeBytes :: [Word8] -> Serializer -> Serializer
writeBytes bytes s = 
  foldr writeU8 (writeUleb128 (fromIntegral (length bytes)) s) (reverse bytes)

writeFixedBytes :: [Word8] -> Serializer -> Serializer
writeFixedBytes bytes (Serializer bs) = Serializer (bs ++ bytes)

-- Simple BCS Deserializer
data Deserializer = Deserializer { desData :: [Word8], desOffset :: Int }
  deriving Show

data DesResult a = Ok a Deserializer | Err String

initDeserializer :: [Word8] -> Deserializer
initDeserializer bytes = Deserializer bytes 0

readBool :: Deserializer -> DesResult Bool
readBool d@(Deserializer bytes off)
  | off >= length bytes = Err "EOF"
  | b == 0 = Ok False (d { desOffset = off + 1 })
  | b == 1 = Ok True (d { desOffset = off + 1 })
  | otherwise = Err "Invalid bool"
  where b = bytes !! off

readU8 :: Deserializer -> DesResult Word8
readU8 d@(Deserializer bytes off)
  | off >= length bytes = Err "EOF"
  | otherwise = Ok (bytes !! off) (d { desOffset = off + 1 })

readU16 :: Deserializer -> DesResult Word16
readU16 d@(Deserializer bytes off)
  | off + 2 > length bytes = Err "EOF"
  | otherwise = Ok (fromIntegral (bytes !! off) .|. (fromIntegral (bytes !! (off + 1)) `shiftL` 8)) (d { desOffset = off + 2 })

readU32 :: Deserializer -> DesResult Word32
readU32 d@(Deserializer bytes off)
  | off + 4 > length bytes = Err "EOF"
  | otherwise = Ok (foldr (\i acc -> acc .|. (fromIntegral (bytes !! (off + i)) `shiftL` (i * 8))) 0 [0..3]) (d { desOffset = off + 4 })

readU64 :: Deserializer -> DesResult Word64
readU64 d@(Deserializer bytes off)
  | off + 8 > length bytes = Err "EOF"
  | otherwise = Ok (foldr (\i acc -> acc .|. (fromIntegral (bytes !! (off + i)) `shiftL` (i * 8))) 0 [0..7]) (d { desOffset = off + 8 })

readU128 :: Deserializer -> DesResult [Word8]
readU128 d@(Deserializer bytes off)
  | off + 16 > length bytes = Err "EOF"
  | otherwise = Ok (take 16 (drop off bytes)) (d { desOffset = off + 16 })

readI8 :: Deserializer -> DesResult Int8
readI8 d = case readU8 d of
  Ok v d' -> Ok (fromIntegral v) d'
  Err e -> Err e

readI16 :: Deserializer -> DesResult Int16
readI16 d = case readU16 d of
  Ok v d' -> Ok (fromIntegral v) d'
  Err e -> Err e

readI32 :: Deserializer -> DesResult Int32
readI32 d = case readU32 d of
  Ok v d' -> Ok (fromIntegral v) d'
  Err e -> Err e

readI64 :: Deserializer -> DesResult Int64
readI64 d = case readU64 d of
  Ok v d' -> Ok (fromIntegral v) d'
  Err e -> Err e

readI128 :: Deserializer -> DesResult [Word8]
readI128 = readU128

readUleb128 :: Deserializer -> DesResult Word32
readUleb128 = go 0 0
  where
    go value shift d@(Deserializer bytes off)
      | off >= length bytes = Err "EOF"
      | otherwise =
          let b = bytes !! off
              newValue = value .|. ((fromIntegral b .&. 0x7F) `shiftL` shift)
              d' = d { desOffset = off + 1 }
          in if b .&. 0x80 == 0
             then Ok newValue d'
             else go newValue (shift + 7) d'

readString :: Deserializer -> DesResult String
readString d = case readUleb128 d of
  Err e -> Err e
  Ok len d' -> readNBytes (fromIntegral len) d'
  where
    readNBytes 0 d' = Ok "" d'
    readNBytes n d' = case readU8 d' of
      Err e -> Err e
      Ok b d'' -> case readNBytes (n - 1) d'' of
        Err e -> Err e
        Ok rest d''' -> Ok (toEnum (fromIntegral b) : rest) d'''

readBytes :: Deserializer -> DesResult [Word8]
readBytes d = case readUleb128 d of
  Err e -> Err e
  Ok len d' -> readNBytesRaw (fromIntegral len) d'
  where
    readNBytesRaw 0 d' = Ok [] d'
    readNBytesRaw n d' = case readU8 d' of
      Err e -> Err e
      Ok b d'' -> case readNBytesRaw (n - 1) d'' of
        Err e -> Err e
        Ok rest d''' -> Ok (b : rest) d'''

readFixedBytes :: Int -> Deserializer -> DesResult [Word8]
readFixedBytes len d@(Deserializer bytes off)
  | off + len > length bytes = Err "EOF"
  | otherwise = Ok (take len (drop off bytes)) (d { desOffset = off + len })

checkEnd :: Deserializer -> Either String ()
checkEnd (Deserializer bytes off)
  | off == length bytes = Right ()
  | otherwise = Left "Remaining input"

-- Hex conversion
hexToBytes :: String -> [Word8]
hexToBytes [] = []
hexToBytes (a:b:rest) = fromIntegral (digitToInt a * 16 + digitToInt b) : hexToBytes rest
hexToBytes _ = []

bytesToHex :: [Word8] -> String
bytesToHex = concatMap (\b -> [intToDigit (fromIntegral (b `shiftR` 4)), intToDigit (fromIntegral (b .&. 0xF))])

-- JSON helpers
escapeJson :: String -> String
escapeJson [] = []
escapeJson ('"':rest) = '\\' : '"' : escapeJson rest
escapeJson ('\\':rest) = '\\' : '\\' : escapeJson rest
escapeJson ('\n':rest) = '\\' : 'n' : escapeJson rest
escapeJson ('\r':rest) = '\\' : 'r' : escapeJson rest
escapeJson ('\t':rest) = '\\' : 't' : escapeJson rest
escapeJson (c:rest) = c : escapeJson rest

findJsonString :: String -> String -> Maybe String
findJsonString key json = 
  case findSubstring ("\"" ++ key ++ "\"") json of
    Nothing -> Nothing
    Just pos -> 
      let afterKey = drop (pos + length key + 2) json
          afterColon = dropWhile (`elem` " \t:") afterKey
      in case afterColon of
           ('"':rest) -> Just $ takeWhile (/= '"') rest
           _ -> Nothing
  where
    findSubstring sub str = go 0 str
      where
        go _ [] = Nothing
        go i s@(_:rest)
          | sub `isPrefixOf` s = Just i
          | otherwise = go (i + 1) rest
    isPrefixOf [] _ = True
    isPrefixOf _ [] = False
    isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys

-- Process a test case
processTestCase :: String -> String
processTestCase tc = 
  let name = maybe "" id (findJsonString "name" tc)
      typ = maybe "" id (findJsonString "type" tc)
      bcsHex = maybe "" id (findJsonString "bcs_hex" tc)
      -- Extract value section (simplified)
      valueJson = extractValue tc
      
      data' = hexToBytes bcsHex
      result = roundtrip typ data'
      
  in case result of
       Left err -> "    {\"name\": \"" ++ escapeJson name ++ "\", \"type\": \"" ++ typ ++ "\", \"bcs_hex\": \"\", \"value\": " ++ valueJson ++ ", \"error\": \"" ++ escapeJson err ++ "\"}"
       Right hex -> "    {\"name\": \"" ++ escapeJson name ++ "\", \"type\": \"" ++ typ ++ "\", \"bcs_hex\": \"" ++ hex ++ "\", \"value\": " ++ valueJson ++ "}"

extractValue :: String -> String
extractValue tc = 
  case findSubstring "\"value\"" tc of
    Nothing -> "null"
    Just pos ->
      let afterKey = drop (pos + 7) tc
          afterColon = dropWhile (`elem` " \t:") afterKey
      in extractJsonValue afterColon
  where
    findSubstring sub str = go 0 str
      where
        go _ [] = Nothing
        go i s@(_:rest)
          | sub `isPrefixOf` s = Just i
          | otherwise = go (i + 1) rest
    isPrefixOf [] _ = True
    isPrefixOf _ [] = False
    isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys
    
    extractJsonValue :: String -> String
    extractJsonValue s = take (findEnd s 0 False) s
    
    findEnd [] _ _ = 0
    findEnd ('"':rest) depth inStr
      | inStr = 1 + findEnd rest depth False
      | otherwise = 1 + findEnd rest depth True
    findEnd ('{':rest) depth False = 1 + findEnd rest (depth + 1) False
    findEnd ('[':rest) depth False = 1 + findEnd rest (depth + 1) False
    findEnd ('}':rest) depth False
      | depth <= 1 = 0
      | otherwise = 1 + findEnd rest (depth - 1) False
    findEnd (']':rest) depth False
      | depth <= 1 = 0
      | otherwise = 1 + findEnd rest (depth - 1) False
    findEnd (',':_) 0 False = 0
    findEnd (c:rest) depth inStr = 1 + findEnd rest depth inStr

roundtrip :: String -> [Word8] -> Either String String
roundtrip "bool" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readBool d
  checkEnd d'
  let s = writeBool v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "u8" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readU8 d
  checkEnd d'
  let s = writeU8 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "u16" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readU16 d
  checkEnd d'
  let s = writeU16 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "u32" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readU32 d
  checkEnd d'
  let s = writeU32 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "u64" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readU64 d
  checkEnd d'
  let s = writeU64 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "u128" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readU128 d
  checkEnd d'
  let s = writeU128 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "i8" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readI8 d
  checkEnd d'
  let s = writeI8 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "i16" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readI16 d
  checkEnd d'
  let s = writeI16 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "i32" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readI32 d
  checkEnd d'
  let s = writeI32 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "i64" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readI64 d
  checkEnd d'
  let s = writeI64 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "i128" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readI128 d
  checkEnd d'
  let s = writeI128 v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "string" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readString d
  checkEnd d'
  let s = writeString v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "bytes" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readBytes d
  checkEnd d'
  let s = writeBytes v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip "fixed_bytes_32" data' = do
  let d = initDeserializer data'
  (v, d') <- toEither $ readFixedBytes 32 d
  checkEnd d'
  let s = writeFixedBytes v emptySerializer
  return $ bytesToHex (getBytes s)
roundtrip typ _ = Left $ "Unknown or complex type: " ++ typ

toEither :: DesResult a -> Either String (a, Deserializer)
toEither (Ok v d) = Right (v, d)
toEither (Err e) = Left e

main :: IO ()
main = do
  input <- getContents
  putStrLn "{"
  putStrLn "  \"version\": \"1.0.0\","
  putStrLn "  \"description\": \"Haskell roundtrip results\","
  
  let categories = ["primitives", "strings", "bytes", "options", "vectors", "structs", "complex"]
  mapM_ (processCategory input (last categories)) categories
  
  putStrLn "}"
  where
    processCategory input lastCat cat = do
      putStr $ "  \"" ++ cat ++ "\": [\n"
      -- Find and process test cases (simplified)
      let testCases = extractTestCases cat input
          processed = zipWith (\tc isLast -> processTestCase tc ++ if isLast then "" else ",") testCases (map (== last testCases) testCases)
      mapM_ putStrLn processed
      putStrLn $ "  ]" ++ if cat == lastCat then "" else ","

extractTestCases :: String -> String -> [String]
extractTestCases cat input = 
  case findCategory cat input of
    Nothing -> []
    Just arrContent -> extractObjects arrContent
  where
    findCategory c s = 
      case findSubstring ("\"" ++ c ++ "\"") s of
        Nothing -> Nothing
        Just pos -> 
          let afterKey = drop pos s
              arrStart = dropWhile (/= '[') afterKey
          in case arrStart of
               ('[':rest) -> Just $ takeArray rest 1
               _ -> Nothing
    
    takeArray [] _ = []
    takeArray (']':_) 0 = []
    takeArray (']':rest) n = ']' : takeArray rest (n - 1)
    takeArray ('[':rest) n = '[' : takeArray rest (n + 1)
    takeArray (c:rest) n = c : takeArray rest n
    
    extractObjects [] = []
    extractObjects s = 
      case dropWhile (/= '{') s of
        [] -> []
        ('{':rest) -> 
          let obj = '{' : takeObject rest 1
              remaining = drop (length obj - 1) rest
          in obj : extractObjects remaining
        _ -> []
    
    takeObject [] _ = []
    takeObject ('}':rest) 1 = "}"
    takeObject ('}':rest) n = '}' : takeObject rest (n - 1)
    takeObject ('{':rest) n = '{' : takeObject rest (n + 1)
    takeObject (c:rest) n = c : takeObject rest n
    
    findSubstring sub str = go 0 str
      where
        go _ [] = Nothing
        go i s@(_:rest)
          | sub `isPrefixOf` s = Just i
          | otherwise = go (i + 1) rest
    isPrefixOf [] _ = True
    isPrefixOf _ [] = False
    isPrefixOf (x:xs) (y:ys) = x == y && isPrefixOf xs ys
