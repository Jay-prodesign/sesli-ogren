# google_mlkit_text_recognition references optional script recognizers from
# shared plugin code. Sesli Öğren uses TextRecognitionScript.latin only.
# Keep release shrinking strict while allowing those intentionally absent
# optional language artifacts.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
