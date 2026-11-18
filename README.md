# Estoque de Equipamentos · MBL

Sistema web de controle de estoque: checkup diário, estoque por local, externas com fotos, movimentações, relatórios em Excel/PDF e login com Google (perfis **ADM** e **Comum**).

- Página estática: `index.html` + `config.js` + `logo.png`
- Banco, login e fotos: **Supabase** (plano gratuito)
- Hospedagem: **Vercel** (plano gratuito)

---

## 1. Banco de dados (Supabase)

1. Abra o projeto no Supabase → **SQL Editor** → **New query**.
2. Cole todo o conteúdo de `supabase/schema.sql` e clique em **Run**.
3. Abra outra query, cole `supabase/dados-iniciais.sql` e clique em **Run** (traz os itens que já estavam cadastrados).

## 2. Login com Google

### 2a. Criar as credenciais no Google
1. Acesse <https://console.cloud.google.com/> e crie um projeto (ex.: "Estoque MBL").
2. **APIs e serviços → Tela de consentimento OAuth**: tipo **Externo**, preencha nome do app e e-mail de suporte. Publique o app (status "Em produção") para qualquer conta Google conseguir entrar.
3. **APIs e serviços → Credenciais → Criar credenciais → ID do cliente OAuth**
   - Tipo: **Aplicativo da Web**
   - **URIs de redirecionamento autorizados**: cole a *Callback URL* que o Supabase mostra em
     **Authentication → Sign In / Providers → Google** (algo como `https://SEU-PROJETO.supabase.co/auth/v1/callback`).
4. Copie o **ID do cliente** e a **Chave secreta do cliente**.

### 2b. Ativar no Supabase
1. **Authentication → Sign In / Providers → Google**: ative, cole o ID do cliente e a chave secreta, salve.
2. **Authentication → URL Configuration**:
   - **Site URL**: o endereço do site na Vercel (ex.: `https://estoque-mbl.vercel.app`)
   - **Redirect URLs**: adicione o mesmo endereço (e `http://localhost:3000` se for testar no computador).

## 3. Configurar o app

Em **Project Settings → API** (ou *Data API*) do Supabase, copie:
- **Project URL**
- chave **anon / public** (ou *publishable*)

Cole no arquivo `config.js`. **Nunca** use a chave `service_role` aqui.

## 4. Publicar na Vercel

1. Entre em <https://vercel.com> com o GitHub.
2. **Add New → Project** → escolha este repositório → **Deploy** (não precisa configurar nada: é um site estático).
3. Copie o endereço gerado e confira se ele está na *Site URL* e nas *Redirect URLs* do Supabase (passo 2b).

## 5. Primeiro acesso

- **A primeira conta que entrar vira ADM automaticamente.** Entre com a sua conta antes de passar o link para a equipe.
- Cada nova pessoa que entrar com o Google aparece na aba **Usuários** como **Sem acesso**. O ADM escolhe **Comum** ou **ADM** para liberar.
- Sempre precisa existir pelo menos um ADM (o sistema bloqueia remover o último).

### O que cada perfil pode fazer

| | Comum | ADM |
|---|:-:|:-:|
| Ver estoque, externas, checkups, relatórios | ✓ | ✓ |
| Lançar entradas e saídas, cadastrar itens | ✓ | ✓ |
| Criar externas, anexar fotos, registrar retorno | ✓ | ✓ |
| Fazer checkup diário | ✓ | ✓ |
| Editar e excluir itens | | ✓ |
| Excluir lançamentos | | ✓ |
| Gerenciar usuários | | ✓ |

## Limites do plano gratuito do Supabase

- 500 MB de banco e 1 GB de fotos (as fotos são reduzidas antes do envio).
- O projeto **pausa após 7 dias sem uso**; basta reativar no painel do Supabase.
