# PWA Implementado - StarTickets

## ✅ Arquivos Criados

| Arquivo | Descrição |
|---------|-----------|
| [priv/static/manifest.json](file:///home/crash/Projects/star-tickets/priv/static/manifest.json) | Configurações do app (nome, ícones, cores) |
| [priv/static/sw.js](file:///home/crash/Projects/star-tickets/priv/static/sw.js) | Service Worker (cache e offline) |
| [priv/static/offline.html](file:///home/crash/Projects/star-tickets/priv/static/offline.html) | Página exibida quando offline |
| `priv/static/images/icons/*` | 8 tamanhos de ícone (72px a 512px) |

## ✅ Arquivos Modificados

- [root.html.heex](file:///home/crash/Projects/star-tickets/lib/star_tickets_web/components/layouts/root.html.heex) - Meta tags PWA e links para manifest/ícones
- [assets/js/app.js](file:///home/crash/Projects/star-tickets/assets/js/app.js) - Registro do Service Worker

---

## 📱 Como Instalar no Celular

### Android (Chrome)
1. Acesse o site no Chrome
2. Toque no menu ⋮ (três pontos)
3. Toque em **"Adicionar à tela inicial"**
4. Confirme o nome e toque em **"Adicionar"**

### iPhone (Safari)
1. Acesse o site no Safari
2. Toque no botão **Compartilhar** (quadrado com seta)
3. Role e toque em **"Adicionar à Tela de Início"**
4. Confirme o nome e toque em **"Adicionar"**

---

## 🔧 Testar no DevTools

1. Abra o site no Chrome
2. F12 → Aba **Application**
3. Verificar:
   - **Manifest** - Sem erros, ícones carregados
   - **Service Workers** - Status "activated"
   - **Cache Storage** - Assets cacheados

![Ícone do PWA](/home/crash/.gemini/antigravity/brain/148d5c1a-7e7b-47a3-9483-e571bafa07ee/pwa_icon_512_1767352562589.png)
