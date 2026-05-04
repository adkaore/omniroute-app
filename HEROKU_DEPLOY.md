# Деплой OmniRoute на Heroku с Backblaze B2

Это руководство покажет, как развернуть OmniRoute на Heroku с автоматическим бэкапом SQLite базы данных в Backblaze B2 (бесплатно, без кредитной карты).

## Почему Backblaze B2?

- ✅ **10 GB бесплатного хранилища** каждый месяц
- ✅ **Не требует кредитную карту** для регистрации
- ✅ S3-совместимый API (работает с Litestream)
- ✅ 1 GB бесплатной загрузки в день

## Шаг 1: Создание аккаунта Backblaze B2

1. Зарегистрируйтесь на https://www.backblaze.com/b2/sign-up.html
2. Подтвердите email
3. Войдите в панель управления

## Шаг 2: Создание Bucket в B2

1. В панели B2 нажмите **"Buckets"** → **"Create a Bucket"**
2. Настройки:
   - **Bucket Name**: `omniroute-backup` (или любое уникальное имя)
   - **Files in Bucket**: **Private**
   - **Default Encryption**: Disabled (или Enable если хотите)
   - **Object Lock**: Disabled
3. Нажмите **"Create a Bucket"**
4. **Сохраните название bucket** - оно понадобится позже

## Шаг 3: Создание Application Key

1. В панели B2 перейдите в **"App Keys"**
2. Нажмите **"Add a New Application Key"**
3. Настройки:
   - **Name of Key**: `omniroute-litestream`
   - **Allow access to Bucket(s)**: выберите ваш bucket `omniroute-backup`
   - **Type of Access**: **Read and Write**
   - **Allow List All Bucket Names**: можно оставить включенным
   - **File name prefix**: оставьте пустым
   - **Duration**: оставьте пустым (бессрочный)
4. Нажмите **"Create New Key"**
5. **ВАЖНО**: Сохраните:
   - **keyID** (например: `005a1b2c3d4e5f6000000001`)
   - **applicationKey** (например: `K005abcdefghijklmnopqrstuvwxyz123456`)
   - Эти данные показываются **только один раз**!

## Шаг 4: Узнайте ваш B2 Endpoint

Endpoint зависит от региона вашего bucket:

- Если bucket в **US West**: `https://s3.us-west-000.backblazeb2.com`
- Если bucket в **US East**: `https://s3.us-east-005.backblazeb2.com`
- Если bucket в **EU Central**: `https://s3.eu-central-003.backblazeb2.com`

Чтобы узнать точный endpoint:
1. Откройте ваш bucket в панели B2
2. Перейдите на вкладку **"Bucket Settings"**
3. Найдите **"Endpoint"** - там будет URL вида `s3.us-west-000.backblazeb2.com`
4. Добавьте `https://` в начало

## Шаг 5: Установка Heroku CLI

Если еще не установлен:

```bash
# Windows (через Chocolatey)
choco install heroku-cli

# Или скачайте установщик с https://devcenter.heroku.com/articles/heroku-cli
```

Войдите в Heroku:

```bash
heroku login
```

## Шаг 6: Создание приложения на Heroku

```bash
# Создайте новое приложение (замените your-app-name на уникальное имя)
heroku create your-app-name

# Или если уже создали через веб-интерфейс:
heroku git:remote -a your-app-name
```

## Шаг 7: Настройка Buildpacks

Heroku нужно установить и Litestream, и Node.js:

```bash
heroku buildpacks:clear
heroku buildpacks:add https://github.com/benbjohnson/litestream-heroku-buildpack.git
heroku buildpacks:add heroku/nodejs
```

## Шаг 8: Настройка переменных окружения

Установите все необходимые переменные:

```bash
# Backblaze B2 настройки (замените на ваши данные)
heroku config:set LITESTREAM_B2_BUCKET="omniroute-backup"
heroku config:set LITESTREAM_B2_ENDPOINT="https://s3.us-west-000.backblazeb2.com"
heroku config:set LITESTREAM_B2_KEY_ID="ваш_keyID"
heroku config:set LITESTREAM_B2_APP_KEY="ваш_applicationKey"

# OmniRoute настройки
heroku config:set DATA_DIR="/app/.omniroute"
heroku config:set NODE_ENV="production"
heroku config:set PORT="20128"

# Генерируйте секреты (выполните локально и скопируйте результаты)
# JWT_SECRET (48 байт base64)
openssl rand -base64 48

# API_KEY_SECRET (32 байта hex)
openssl rand -hex 32

# Установите сгенерированные секреты
heroku config:set JWT_SECRET="ваш_сгенерированный_jwt_secret"
heroku config:set API_KEY_SECRET="ваш_сгенерированный_api_key_secret"

# Начальный пароль для входа в dashboard (измените на свой)
heroku config:set INITIAL_PASSWORD="ваш_безопасный_пароль"

# Опционально: требовать API ключ для всех запросов
heroku config:set REQUIRE_API_KEY="false"

# Опционально: уровень логирования
heroku config:set APP_LOG_LEVEL="info"
```

## Шаг 9: Деплой на Heroku

```bash
# Убедитесь, что все изменения закоммичены
git add .
git commit -m "Configure for Heroku deployment with Backblaze B2"

# Задеплойте на Heroku
git push heroku main

# Или если ваша ветка называется master:
git push heroku master
```

## Шаг 10: Проверка деплоя

```bash
# Откройте приложение в браузере
heroku open

# Посмотрите логи
heroku logs --tail

# Проверьте, что Litestream работает
heroku logs --tail | grep -i litestream
```

В логах вы должны увидеть:
```
✓ Database restored from Backblaze B2
Starting Litestream replication and Next.js server...
```

## Шаг 11: Проверка бэкапов

Через несколько минут после запуска:

1. Зайдите в панель Backblaze B2
2. Откройте ваш bucket `omniroute-backup`
3. Вы должны увидеть папку `omniroute-db/` с файлами бэкапа

## Важные замечания

### Ограничения GitHub Student Pack

- ✅ Вы получаете **$13/месяц credits** на 12 месяцев (всего $156)
- ✅ Basic dyno стоит **$7/месяц** - у вас останется $6/месяц на другие ресурсы
- ❌ **$1 верификационный платеж НЕ возвращается** - это authorization hold, который исчезнет через 5-7 дней

### Как работает Litestream

- **Автоматическая репликация**: каждые 10 секунд изменения отправляются в B2
- **Снапшоты**: каждый час создается полный снапшот базы
- **Восстановление**: при перезапуске dyno база автоматически восстанавливается из B2
- **Retention**: снапшоты хранятся 7 дней (168 часов)

### Мониторинг использования B2

Backblaze B2 бесплатный лимит:
- 10 GB хранилища
- 1 GB загрузки в день
- 2500 Class A операций в день (загрузка файлов)
- 2500 Class B операций в день (скачивание файлов)

Для мониторинга:
1. Зайдите в панель B2
2. Перейдите в **"Reports"** → **"Usage"**
3. Проверяйте использование регулярно

### Масштабирование

Если база данных вырастет больше 10 GB:
1. Backblaze попросит добавить карту
2. Стоимость: $0.005/GB/месяц (очень дешево)
3. Или можете настроить retention на меньший срок в `litestream.yml`

## Troubleshooting

### База не восстанавливается

```bash
# Проверьте переменные окружения
heroku config

# Проверьте логи Litestream
heroku logs --tail | grep -i litestream

# Проверьте, что bucket существует и доступен
```

### Ошибка "Access Denied"

- Проверьте, что Application Key имеет права **Read and Write**
- Проверьте, что `LITESTREAM_B2_BUCKET` совпадает с именем bucket
- Проверьте, что endpoint правильный для вашего региона

### Dyno перезапускается каждые 24 часа

Это нормально для Heroku. Litestream автоматически восстановит базу при каждом перезапуске.

### База данных пустая после деплоя

Это нормально для первого деплоя. После первого запуска:
1. Настройте приложение через dashboard
2. Litestream начнет автоматически бэкапить изменения
3. При следующем перезапуске база восстановится

## Полезные команды

```bash
# Перезапустить dyno
heroku restart

# Посмотреть статус dyno
heroku ps

# Открыть bash в dyno (для отладки)
heroku run bash

# Посмотреть размер базы данных
heroku run bash -c "ls -lh /app/.omniroute/"

# Посмотреть конфигурацию Litestream
heroku run bash -c "cat litestream.yml"
```

## Обновление приложения

```bash
# Закоммитьте изменения
git add .
git commit -m "Update application"

# Задеплойте
git push heroku main

# База данных автоматически восстановится после деплоя
```

## Безопасность

1. **Никогда не коммитьте секреты** в git
2. Используйте сильный `INITIAL_PASSWORD`
3. Смените пароль после первого входа в dashboard
4. Регулярно ротируйте `JWT_SECRET` и `API_KEY_SECRET`
5. Включите `REQUIRE_API_KEY=true` для production

## Дополнительные ресурсы

- [Heroku Node.js Support](https://devcenter.heroku.com/articles/nodejs-support)
- [Litestream Documentation](https://litestream.io/guides/)
- [Backblaze B2 Documentation](https://www.backblaze.com/b2/docs/)
- [GitHub Student Developer Pack](https://education.github.com/pack)

## Поддержка

Если возникли проблемы:
1. Проверьте логи: `heroku logs --tail`
2. Проверьте переменные окружения: `heroku config`
3. Создайте issue в репозитории OmniRoute
