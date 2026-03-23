# sh-delpierropark (LunaPark Lua OO)

# by shruog my Discord: https://discord.gg/QkT8hUu9FR

[🇺🇸 English](#-english) | [🇧🇷 Português](#-português) | [🇪🇸 Español](#-español)

![Demo Logo](upload://9LbIiNZXVD2GhRgPxHwlsLTOsgO.jpeg)

**Demonstration video:** [https://streamable.com/f8io04](https://streamable.com/f8io04)

| Feature | Info |
|-------------|------------|
| Code is accessible | Yes |
| Subscription-based | No |
| Lines (approximately)| ~1,500 |
| Requirements | None |
| Support | Yes |

---
## 🇺🇸 English

> ⚠️ **Note:** This is not a plug-and-play script. It needs some fixes but has open code in Lua.

A FiveM resource that adds realistic and synchronized functionality to the Ferris Wheel and Roller Coaster at Del Perro Pier.

### This script was converted to Lua OOP by me
I implemented some functions to improve performance. When there are no players near the Ferris wheels or roller coasters, the script puts the thread to "sleep". It still needs more testing and improvements.

### 🌟 Key Features
- **Fully Functional Roller Coaster:** Smooth cart movement, waiting times, and multi-seat support.
- **Accurate Ferris Wheel:** Cabins rotate simultaneously, respecting boarding and unboarding.
- **"Host-Based" (Server Authoritative) Synchronization:** To prevent desync issues, the active player with the lowest *server-id* acts as the physics *host*. The server flawlessly relays physics events to all other clients.
- **Object-Oriented Lua:** Source code structured in classes for better modularity, easy to iterate and expand.
- **Total Immersion:** Utilizes native audio sets (`AudioScenes` / `SoundSets`), custom camera transitions, and native animations.

### 🐛 Known Issues
- Players need to be attached to the Ferris wheel cabin and rollercoaster car.
- Needs more tests, but it has sync; it only needs players to be attached to the object positions.
- I tried improving performance by putting it in sleep mode, but I created a simple bug regarding instructional buttons (I prefer to use instructional buttons with a very simple NUI).

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

### 📌 Support & Links

**My Discord:** [Shruog Corphate Store](https://discord.gg/xddPEQEgUg)  
*Maybe I can help you with something more about this script...*

- **Download Here (Repository):** [shruog/sh-delpierropark](https://github.com/shruog/sh-delpierropark)
- **Original Author Repository:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)

---
## 🇧🇷 Português

> ⚠️ **Aviso:** Este não é um script "plug and play". Precisa de algumas correções, mas o código é aberto em Lua.

Um resource para FiveM que adiciona funcionamento realístico e sincronizado à Roda Gigante (Ferris Wheel) e à Montanha Russa (Roller Coaster) no Píer Del Perro.

### Este script foi convertido para Lua OOP por mim
Implementei algumas funções para melhorar o desempenho. Quando não há jogadores perto das rodas gigantes ou montanhas-russas, o script coloca a thread em estado de "sleep" (dormir). Ainda precisa de mais testes e melhorias.

### 🌟 Características Principais
- **Montanha Russa Completa:** Carrinhos com movimentação suave, tempos de espera e suporte para múltiplos assentos.
- **Roda Gigante Precisa:** As cabines rodam simultaneamente, respeitando embarque e desembarque.
- **Sincronização "Host-Based" (Server Authoritative):** Para evitar problemas de dessincronização, o jogador ativo com o menor *server-id* atua como o *host* responsável pela física. O servidor retransmite os eventos de física perfeitamente para todos os outros clientes.
- **Lua Orientado a Objetos:** Código fonte estruturado em classes para melhor modularidade, fácil de iterar e expandir.
- **Imersão Total:** Utiliza os conjuntos de áudio (`AudioScenes` / `SoundSets`), transições de câmera customizadas e animações nativas.

### 🐛 Problemas Conhecidos (Known Issues)
- Os jogadores precisam ser "atachados" (anexados) à cabine da roda gigante e ao carrinho da montanha-russa.
- Precisa de mais testes, mas possui sincronização; só é necessário anexar os jogadores nas posições corretas dos objetos.
- Tentei melhorar a performance colocando um modo sleep, mas acabei criando um pequeno bug nos botões de instrução (prefiro usar botões de instrução com uma NUI bem simples).

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

### 📌 Suporte & Links

**Meu Discord:** [Shruog Corphate Store](https://discord.gg/xddPEQEgUg)  
*Talvez eu possa te ajudar com mais alguma coisa sobre este script...*

- **Download Aqui (Repositório):** [shruog/sh-delpierropark](https://github.com/shruog/sh-delpierropark)
- **Repositório do Autor Original:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)

---
## 🇪🇸 Español

> ⚠️ **Aviso:** Este no es un script "plug and play". Necesita algunas correcciones, pero tiene código abierto en Lua.

Un recurso para FiveM que añade un funcionamiento realista y sincronizado a la Noria (Ferris Wheel) y a la Montaña Rusa (Roller Coaster) en el muelle de Del Perro.

### Este script fue convertido a Lua OOP por mí
Implementé algunas funciones para mejorar el rendimiento. Cuando no hay jugadores cerca de la noria o la montaña rusa, el script pone el hilo en modo "sleep" (suspensión). Aún necesita más pruebas y mejoras.

### 🌟 Características Principales
- **Montaña Rusa Funcional:** Carritos con movimiento suave, tiempos de espera y soporte para múltiples asientos.
- **Noria Precisa:** Las cabinas giran simultáneamente, respetando las zonas de subida y bajada.
- **Sincronización "Host-Based" (Autoridad del Servidor):** Para evitar problemas de desincronización, el jugador activo con el *server-id* más bajo actúa como el *host* responsable de las físicas. El servidor transmite perfectamente los eventos físicos a todos los demás clientes.
- **Lua Orientado a Objetos:** Código fuente estructurado en clases para una mejor modularidad, fácil de iterar y expandir.
- **Inmersión Total:** Utiliza los conjuntos de audio nativos (`AudioScenes` / `SoundSets`), transiciones de cámara personalizadas y animaciones nativas.

### 🐛 Problemas Conocidos (Known Issues)
- Los jugadores necesitan estar adheridos (attached) a la cabina de la noria y al carrito de la montaña rusa.
- Necesita más pruebas, pero tiene sincronización; solo falta adherir a los jugadores en las posiciones correctas de los objetos.
- Intenté mejorar el rendimiento poniendo un modo sleep, pero creé un pequeño error con los botones de instrucción (prefiero usar botones de instrucción con una NUI muy simple).

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

### 📌 Soporte y Enlaces

**Mi Discord:** [Shruog Corphate Store](https://discord.gg/xddPEQEgUg)  
*Tal vez pueda ayudarte con algo más sobre este script...*

- **Descargar Aquí (Repositorio):** [shruog/sh-delpierropark](https://github.com/shruog/sh-delpierropark)
- **Repositorio del Autor Original:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)
