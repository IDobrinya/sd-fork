# Stable Diffusion WebUI с S3 интеграцией

Этот форк добавляет встроенную поддержку S3 для загрузки и сохранения изображений через API.

## Новые возможности

- Загрузка изображений из S3 для img2img API
- Автоматическое сохранение результатов в S3  
- Поддержка переменных окружения для настройки S3

## Требуемые переменные окружения

```bash
S3_ENDPOINT=https://your-s3-endpoint.com
S3_ACCESS_KEY=your-access-key
S3_SECRET_ACCESS_KEY=your-secret-access-key
S3_BUCKET=your-bucket-name
```

## Сборка образа

```bash
# Клонируйте репозиторий
git clone https://github.com/IDobrinya/sd-fork.git
cd sd-fork

# Создайте .env файл с настройками S3
cp .env.example .env
# Отредактируйте .env файл

# Соберите образ
docker compose build

# Запустите контейнер
docker compose up
```

## Изменения в API

### img2img API
- `init_images` теперь принимает строку с S3 URL вместо массива base64 изображений
- Ответ содержит `s3_url` с ссылкой на сохраненный результат

### Пример использования

```python
import requests

# img2img запрос с S3 URL
response = requests.post('http://localhost:7860/sdapi/v1/img2img', json={
    'init_images': 'https://your-s3-endpoint.com/bucket/path/image.jpg',
    'prompt': 'beautiful landscape',
    'denoising_strength': 0.75
})

result = response.json()
print(f"Result saved to: {result['s3_url']}")
```

## Отличия от оригинального stable-diffusion-webui

- Добавлены модули для работы с S3
- Модифицирован img2img API
- Добавлены зависимости: boto3, python-dotenv, botocore