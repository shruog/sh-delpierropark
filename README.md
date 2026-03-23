# sh-delpierropark (LunaPark Lua OO)

# by shruog my Discord: https://discord.gg/QkT8hUu9FR

[🇺🇸 English](#-english) | [🇧🇷 Português](#-português) | [🇪🇸 Español](#-español)

---

## 🇺🇸 English

A FiveM resource that adds realistic and synchronized functionality to the Ferris Wheel and Roller Coaster at Del Perro Pier.

This script is based on the original logic from [LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM), but it has been completely rewritten and modernized in **Object-Oriented (OO) Lua**, focusing on stability and flawless player synchronization.

### 🌟 Key Features
- **Fully Functional Roller Coaster:** Smooth cart movement, waiting times, and multi-seat support.
- **Accurate Ferris Wheel:** Cabins rotate simultaneously, respecting boarding and unboarding.
- **"Host-Based" (Server Authoritative) Synchronization:** To prevent desync issues, the active player with the lowest *server-id* acts as the physics *host*. The server flawlessly relays physics events to all other clients.
- **Object-Oriented Lua:** Source code structured in classes for better modularity, easy to iterate and expand.
- **Total Immersion:** Utilizes native audio sets (`AudioScenes` / `SoundSets`), custom camera transitions, and native animations.

### 📋 How to Install
1. Download the script and place the `sh-delpierropark` folder inside your server's `resources` directory (or a subfolder).
2. Add `ensure sh-delpierropark` to your `server.cfg`.
3. Restart your server or start it via the admin console.

### ⚙️ Configuration
The entire script is configurable via the `shared/config.lua` file. You can adjust:
- Speed and wait times
- Interaction radius (proximity to enter the rides)
- Map Blips (Names, Sprites)
- Boarding and exit positions
- Cameras and prop model IDs

### 📌 Support & Contact
Join our Discord for support on this resource, news, community chats, and to interact with us!
🔗 [**Click here to join the Discord: https://discord.gg/QkT8hUu9FR**](https://discord.gg/QkT8hUu9FR)

#### Credits
- **Author (Lua OO Version):** shruog
- **Original Idea & Repo:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)

---

## 🇧🇷 Português

Um resource para FiveM que adiciona funcionamento realístico e sincronizado à Roda Gigante (Ferris Wheel) e à Montanha Russa (Roller Coaster) no Píer Del Perro.

Este script é baseado na lógica original do [LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM), porém foi totalmente reescrito e modernizado em **Lua Orientado a Objetos (OO)**, focando em estabilidade e uma sincronização de jogadores impecável.

### 🌟 Características Principais
- **Montanha Russa Completa:** Carrinhos com movimentação suave, tempos de espera e suporte para múltiplos assentos.
- **Roda Gigante Precisa:** As cabines rodam simultaneamente, respeitando embarque e desembarque.
- **Sincronização "Host-Based" (Server Authoritative):** Para evitar problemas de dessincronização, o jogador ativo com o menor *server-id* atua como o *host* responsável pela física. O servidor retransmite os eventos de física perfeitamente para todos os outros clientes.
- **Lua Orientado a Objetos:** Código fonte estruturado em classes para melhor modularidade, fácil de iterar e expandir.
- **Imersão Total:** Utiliza os conjuntos de áudio (`AudioScenes` / `SoundSets`), transições de câmera customizadas e animações nativas.

### 📋 Como Instalar
1. Baixe o script e insira a pasta `sh-delpierropark` dentro do diretório `resources` (ou em alguma subpasta) do seu servidor FiveM.
2. Adicione `ensure sh-delpierropark` ao seu `server.cfg`.
3. Reinicie o servidor ou dê start pelo console administrativo.

### ⚙️ Configuração
Todo o script é configurável através do arquivo `shared/config.lua`. Nele você pode ajustar:
- Velocidade e tempo de espera
- Raios de interação (proximidade para entrar nos brinquedos)
- Blips do Mapa (Nomes, Sprites)
- Posições de embarque e saída
- Câmeras e IDs dos prop models

### 📌 Suporte & Contato
Acesse nosso Discord para suporte sobre este resource, novidades, conversas com a comunidade e para interagir conosco!
🔗 [**Clique aqui para entrar no Discord: https://discord.gg/QkT8hUu9FR**](https://discord.gg/QkT8hUu9FR)

#### Créditos
- **Autor (Versão Lua OO):** shruog
- **Ideia & Repo Original:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)

---

## 🇪🇸 Español

Un recurso para FiveM que añade un funcionamiento realista y sincronizado a la Noria (Ferris Wheel) y a la Montaña Rusa (Roller Coaster) en el muelle de Del Perro.

Este script está basado en la lógica original de [LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM), pero ha sido reescrito por completo y modernizado en **Lua Orientado a Objetos (OO)**, enfocándose en la estabilidad y en una sincronización impecable entre los jugadores.

### 🌟 Características Principales
- **Montaña Rusa Funcional:** Carritos con movimiento suave, tiempos de espera y soporte para múltiples asientos.
- **Noria Precisa:** Las cabinas giran simultáneamente, respetando las zonas de subida y bajada.
- **Sincronización "Host-Based" (Autoridad del Servidor):** Para evitar problemas de desincronización, el jugador activo con el *server-id* más bajo actúa como el *host* responsable de las físicas. El servidor transmite perfectamente los eventos físicos a todos los demás clientes.
- **Lua Orientado a Objetos:** Código fuente estructurado en clases para una mejor modularidad, fácil de iterar y expandir.
- **Inmersión Total:** Utiliza los conjuntos de audio nativos (`AudioScenes` / `SoundSets`), transiciones de cámara personalizadas y animaciones nativas.

### 📋 Cómo Instalar
1. Descarga el script e inserta la carpeta `sh-delpierropark` dentro del directorio `resources` (o en alguna subcarpeta) de tu servidor de FiveM.
2. Añade `ensure sh-delpierropark` a tu `server.cfg`.
3. Reinicia el servidor o inícialo mediante la consola de administración.

### ⚙️ Configuración
Todo el script es configurable a través del archivo `shared/config.lua`. En este archivo puedes ajustar:
- Velocidad y tiempos de espera
- Radios de interacción (proximidad para usar las atracciones)
- Marcadores de Mapa (Nombres, Sprites)
- Posiciones de embarque y salida
- Cámaras e IDs de los modelos de props

### 📌 Soporte y Contacto
¡Únete a nuestro Discord para soporte sobre este recurso, noticias, y para interactuar con la comunidad!
🔗 [**Haz clic aquí para unirte al Discord: https://discord.gg/QkT8hUu9FR**](https://discord.gg/QkT8hUu9FR)

#### Créditos
- **Autor (Versión Lua OO):** shruog
- **Idea y Repositorio Original:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)
