# Manrope

Автор: The Manrope Project Authors; дизайнер Mikhail Sharanda.
Лицензия: SIL Open Font License 1.1, полный текст в OFL.txt.

Исходник загружен 2026-11-08 из официального Google Fonts:
https://github.com/google/fonts/tree/main/ofl/manrope
Файл: Manrope[wght].ttf (в этой папке Manrope.ttf).
SHA-256: 3ae11c49db0455a3cc33e37d380f20fdb8c7f8b41dc07625c177e3d87a9d6ae6

Кириллица и диапазон wght 200–800 подтверждены METADATA.pb источника.
Статические экземпляры 400/700/800 получены локально с fonttools 4.60.1:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

for weight, name in [(400, 'Regular'), (700, 'Bold'), (800, 'ExtraBold')]:
    font = TTFont('Manrope.ttf')
    instance = instantiateVariableFont(
        font, {'wght': weight}, inplace=True, updateFontNames=True)
    instance.save(f'Manrope-{name}.ttf')
```

fonttools нужен только для повторного получения assets, не для сборки приложения.
В bundle входят три статических TTF и OFL.txt. Вариативный исходник остаётся только
в репозитории. Это обеспечивает одинаковый выбор начертаний в приложении и golden-тестах.
