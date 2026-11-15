# BetterMacro : idées de fonctionnalités

Fichier de travail, exclu du paquet publié (voir `.pkgmeta`).

Contrainte à garder en tête pour tout ce qui suit : **un addon n'a pas accès à
Internet**. Tout ce qui est « communautaire » passe soit par d'autres joueurs en
jeu (messages d'addon), soit par du copier-coller de codes `BM1!`, soit par du
contenu livré avec l'addon.

Ordre conseillé : **1 → 2 → 3**. Le catalogue (2) repose sur les modèles à
trous (1), et les liens de chat (3) réutilisent l'aperçu construit en 1.

| Idée | État |
|---|---|
| 1. Modèles à trous et aperçu | **Implémentée** (branche `dev/1.1.0`), à tester en jeu |
| 2. Catalogue par classe | **Implémenté** (43 + 96 macros importées, 9 classes), à tester en jeu |
| 3. Liens de chat et guilde | **En attente** : à rediscuter plus tard |

---

## 1. Modèles à trous et aperçu au survol

### Pourquoi
Aujourd'hui, `Core/Templates.lua` remplit déjà chaque modèle avec un sort de la
classe (table `CLASS` : `harm`, `help`, `alt`, `cc`, `interrupt`, `seq`). Mais si
le personnage ne connaît pas le sort, l'emplacement reste simplement vide et
affiche « Choisir... » : le joueur ne sait pas *quel genre* de sort mettre. Et on
ne voit ce que fait un modèle qu'après l'avoir ouvert, ce qui remplace la macro
en cours.

### Ce que voit le joueur
- Un emplacement vide d'un modèle affiche son **rôle** : « Ton sort de soin »,
  « Ton interruption », « Ton contrôle »… en orange, avec une icône dédiée.
- Le sélecteur de sorts s'ouvre **filtré sur ce rôle** quand c'est possible
  (sorts de soin en tête pour un trou « soin »).
- Tant qu'un trou n'est pas rempli, l'explication le dit (« Ligne 1 : choisis ton
  sort de soin ») et **Enregistrer** prévient au lieu d'écrire une macro cassée.
- **Survol d'un modèle** dans la palette : une infobulle montre l'explication en
  clair (« Si ton survol est un allié vivant, lance… sinon… »), sans rien ouvrir.
- **Mes modèles** : on peut transformer un emplacement en trou (clic droit sur un
  sort → « En faire un trou de rôle… »), pour que ses propres modèles servent à
  d'autres classes ou d'autres personnages.

### Comment
- **Modèle de données** (`Core/Util.lua`) : une action peut porter un rôle sans
  sort, `action = { kind = "hole", role = "help" }`. Elle n'est jamais écrite
  telle quelle dans le texte de la macro.
  - `Generator` : une ligne avec un trou génère `/cast ` vide, ou est sautée avec
    un avertissement. À trancher ; la sauter est plus sûr.
  - `Explainer` : nouvel avertissement `W_HOLE` (« Ligne %d : choisis %s »).
  - `Storage.Save` : refuse tant qu'il reste un trou (nouvelle erreur `ERR_HOLES`).
- **Rôles** : `help`, `harm`, `alt` (second sort), `cc`, `interrupt`, `self`
  (buff sur soi). Chacun a un libellé (`L.ROLE_help` = « ton sort de soin ») et
  une icône.
- **Templates.lua** : `spell(id)` renvoie `{ kind = "hole", role = r }` au lieu
  de `nil` quand le sort n'est pas connu. Le reste du fichier ne change pas.
- **Builder.lua** (`actionSlot`) : style `hole` (orange) et libellé du rôle quand
  `action.kind == "hole"` ; le sélecteur reçoit le rôle en indice.
- **Aperçu** : une fonction `T.Preview(index)` construit le modèle *sans l'ouvrir*
  et renvoie `E.Explain(...)`. La palette l'affiche dans l'infobulle
  (`W.Tooltip` accepte déjà une fonction).
- **Picker.lua** : filtre facultatif par rôle. Il faut une heuristique sort →
  rôle : `D.Nature` donne déjà aide/offensif ; pour `interrupt` et `cc`, utiliser
  une petite liste d'IDs dans les données de classe.

### Étapes
1. Type d'action `hole` + rendu dans le Builder + avertissement dans l'Explainer.
2. `Templates.lua` produit des trous ; blocage à l'enregistrement.
3. Aperçu au survol dans la palette.
4. Trous dans « Mes modèles » (clic droit → en faire un trou).
5. Filtre par rôle dans le sélecteur de sorts.

### Questions ouvertes
- Un code de partage `BM1!` transporte le *texte* de la macro, pas les blocs :
  un trou ne peut pas y passer. Faut-il une version `BM2!` qui transporte les
  blocs (nécessaire aussi pour les packs de modèles), ou interdire de partager
  une macro qui a des trous ?
- Quel nom donner aux macros nées d'un modèle : vide (comme aujourd'hui) ou le
  nom du modèle pré-rempli ?

**Effort estimé** : moyen (étapes 1 à 3 en premier, le reste ensuite).

### Ce qui a été fait
- Action `{ kind = "hole", role }` dans `Core/Util.lua` (`U.Hole`, `U.HasHoles`,
  `U.ROLES`). Le texte généré laisse le nom vide ; l'explication nomme le rôle
  (« lance ton sort de soin sur… ») et affiche l'avertissement `W_HOLES`.
- **Décisions** : une macro avec un trou ne peut ni être enregistrée
  (`ERR_HOLES`) ni partagée (`SHARE_HOLES`) ; le passage à `BM2!` reste à faire
  si on veut partager des modèles à trous. Le nom reste vide.
- Builder : emplacement orange avec l'icône du rôle ; clic droit sur un
  emplacement de sort → « Vider » ou « Laisser à remplir : <rôle> » (c'est ainsi
  qu'on crée des trous dans « Mes modèles »). Pas sur l'emplacement de
  l'infobulle.
- Sélecteur de sorts : en remplissant un trou, le sort de la classe pour ce rôle
  arrive en premier, puis les sorts de la bonne nature (aide / offensif).
- Palette : l'infobulle d'un modèle (intégré ou personnel) montre son
  explication pour ce personnage, sans l'ouvrir (`T.ExplainText`).
- Test ajouté dans `tests/regression.lua` (un trou bloque l'enregistrement).

---

## 2. Catalogue par classe

### Pourquoi
Les 9 modèles actuels sont génériques. Un joueur qui débute veut « les macros
utiles pour mon prêtre », expliquées, prêtes à l'emploi. C'est aussi la vitrine
de l'addon : aucun site de macros ne peut montrer ce qu'une macro fera *avec ton
personnage, en ce moment*.

### Ce que voit le joueur
- Un onglet ou un bouton **Catalogue** ouvre une fenêtre :
  - filtres **Classe** (la sienne par défaut), **Rôle** (soin / tank / dégâts /
    utilitaire) et **Situation** (donjon, JcJ, quête, familier…) ;
  - chaque fiche : nom, une phrase de résumé, l'explication complète, les sorts
    utilisés avec le niveau requis.
- Les fiches dont tu ne connais pas encore les sorts sont **grisées**
  (« Disponible au niveau 20 ») ou masquées par une case « Seulement ce que je
  peux utiliser ».
- **Utiliser** ouvre la macro comme nouvelle macro non enregistrée (même chemin
  que les modèles), avec le test en direct déjà actif.
- Une étoile pour garder une fiche dans ses favoris.

### Comment
- **Données** : nouveau fichier `Core/Catalog.lua`, une entrée par macro :
  `{ id, class, roles = {...}, tags = {...}, key = "CAT_PRIEST_MO_HEAL", build = function(c) ... end, spells = { 2061, ... } }`.
  Les `build` réutilisent les briques de `Templates.lua` (`branch`, `cast`,
  `spell`) : il faut les exposer (`T.branch`, `T.cast`, `T.spell`).
- La table `CLASS` de `Templates.lua` grossit et devient la source unique des
  sorts par classe et par rôle ; les modèles génériques et le catalogue s'en
  servent tous les deux.
- **Disponibilité** : `D.IsKnown(id)` pour chaque sort de `spells`. Pour « niveau
  requis », une petite table `id → niveau` dans les données (le client ne le
  donne pas de façon fiable pour un sort non appris).
- **Textes** : résumé et nom de chaque fiche dans les locales (`CAT_*`), en
  anglais et en français.
- **Interface** : fenêtre séparée `UI/CatalogFrame.lua` (ajoutée au `.toc`,
  donc redémarrage complet du jeu la première fois). Liste à gauche, fiche à
  droite avec `E.Explain` pour l'explication.
- **Favoris** : `BetterMacroDB.catalogFavorites = { [id] = true }`.

### Étapes
1. Exposer les briques de `Templates.lua` et y déplacer les données de classe.
2. `Core/Catalog.lua` avec 3 à 5 macros pour 2 classes, pour valider le format.
3. Fenêtre Catalogue (filtre classe, fiche, bouton Utiliser).
4. Disponibilité selon le grimoire et niveau requis.
5. Remplir les 9 classes (5 à 10 macros chacune), puis filtres rôle et
   situation, puis favoris.

### Questions ouvertes
- Qui écrit et vérifie le contenu ? C'est le gros du travail : il faut tester
  chaque macro en jeu, sur WoW Forever, et à plusieurs niveaux.
- IDs de sorts : `Templates.lua` utilise les rangs de base. Les rangs supérieurs
  se gèrent déjà via l'option « Rangs des sorts » ; à vérifier sur chaque fiche.
- Un catalogue intégré grossit l'addon. Faut-il un module séparé
  (`BetterMacro_Catalog`), chargé seulement à l'ouverture ?

**Effort estimé** : moyen pour le code, important pour le contenu.

### Ce qui a été fait
- `Core/Catalog.lua` : 43 macros sur les 9 classes, construites avec les briques
  de `Core/Templates.lua` (`T.spell`, `T.branch`, `T.cast`, `T.sequence`), donc
  un sort non appris devient un trou.
- `UI/CatalogFrame.lua` : filtres classe (la sienne par défaut), rôle,
  situation, case « Seulement ce que je peux utiliser » ; fiche avec
  description, sorts manquants, explication complète ; favoris (en tête de
  liste, `BetterMacroDB.catalogFavorites`) ; « Utiliser cette macro » ouvre une
  nouvelle macro non enregistrée.
- Accès : bouton « Catalogue par classe » en haut de la palette, ou
  `/bm catalogue` (`/bm catalog`).
- **Décision** : au lieu d'un niveau requis (peu fiable côté client), la fiche
  liste par leur nom les sorts **pas encore appris**.
- **À vérifier en jeu** : chaque ID de sort sur WoW Forever (rangs de base
  supposés), et que chaque macro fait bien ce que dit sa description.

### Import depuis classicwowforever.com
- 96 macros des sections « Toute la classe » (licence CC BY 4.0, créditée dans
  le README et sur chaque fiche) dans `Core/CatalogImported.lua`, écrites en
  texte avec `{sID|Nom anglais}` / `{iID|Nom anglais}` : l'ID donne le nom
  dans la langue du client, le nom anglais sert de secours.
- Le site annonce **670 macros** ; les sections par spécialisation (JcE et JcJ)
  n'étaient pas lisibles. À récupérer plus tard si possible.
- Sorts propres à Forever sans ID connu (`s0`) : Ranimer, Frappe sacrée,
  Coup de couteau, Ivresse de la victoire, Téléportation : Dalaran, Bouclier
  d'eau, appels de totems. Ils ne marchent que sur un client anglais tant
  qu'on n'a pas leur ID.
- Restent en « texte brut » : `/click` et `/party`.
- Pour lire ces macros en blocs, ajout des conditions `nomod`, `nostance:n`,
  `swimming`, `outdoors`/`indoors`, `pet`/`nopet`, `button:n`, du `!` devant un
  sort, de `/petpassive` et des conditions sur les commandes. Les tooltips à
  conditions deviennent l'infobulle automatique.

---

## 3. Liens cliquables dans le chat et partage en guilde

> **En attente** : idée conservée, à rediscuter avant de commencer.

### Pourquoi
Les codes `BM1!` marchent mais sont longs (jusqu'à 2400 caractères) : on ne peut
pas les coller dans le chat du jeu, limité à 255 caractères. Un lien court et
cliquable, c'est le premier pas vers une communauté qui vit vraiment en jeu.

### Ce que voit le joueur
- Dans **Plus**, « Lier dans le chat » insère `[BetterMacro : Soin survol]` dans
  la zone de saisie du chat, comme un lien d'objet.
- Un joueur qui a l'addon voit un **lien coloré**. Un clic ouvre un aperçu :
  nom, icône, explication complète, avertissements, puis **Importer** (nouvelle
  macro non enregistrée, comme un import de code).
- Un joueur sans l'addon voit juste le texte entre crochets, sans gêne.
- **Onglet Guilde** dans la liste de gauche : les macros que tes camarades de
  guilde ont choisi de publier, triées par classe, avec le même aperçu.

### Comment
- **Le lien ne contient pas la macro** : le serveur supprime les liens
  personnalisés `|H…|h` envoyés par les joueurs. On envoie donc un texte
  simple `[BetterMacro: Nom]`, et chaque client qui a l'addon le transforme en
  lien à l'affichage avec `ChatFrame_AddMessageEventFilter`, sur les canaux
  dire, groupe, raid, guilde et chuchotement.
- **Clic** : intercepter le clic sur ce lien (accroche de `SetItemRef`, ou
  `EventRegistry` selon le client ; à vérifier sur WoW Forever).
- **Récupérer la macro** : le clic envoie une demande à l'auteur du message par
  `C_ChatInfo.SendAddonMessage` (préfixe `BetterMacro`, enregistré avec
  `C_ChatInfo.RegisterAddonMessagePrefix`), en chuchotement d'addon. L'auteur
  répond avec le code `BM1!`, découpé en morceaux de 255 octets au plus et
  envoyé à petite cadence pour ne pas être déconnecté. L'auteur doit donc être
  en ligne ; sinon, on affiche « Auteur hors ligne ».
- **Sécurité** : on ne fait que réutiliser `Sh.Decode`, qui passe déjà par le
  parseur, retire les `|` et n'enregistre jamais rien tout seul. L'auteur ne
  répond que pour les macros qu'il a lui-même liées dans la session (liste
  gardée en mémoire), pas pour n'importe quel nom demandé.
- **Partage en guilde** :
  - case « Publier pour ma guilde » sur une macro (opt-in, rien n'est publié par
    défaut) ;
  - à la connexion, chaque client envoie sur le canal d'addon `GUILD` une courte
    liste (nom, classe, empreinte) de ses macros publiées ;
  - le contenu n'est demandé qu'à l'ouverture d'une fiche, et gardé en cache
    dans `BetterMacroDB.guildCache` avec la date, pour les consulter même quand
    l'auteur n'est plus connecté.
- **Envoi à cadence limitée** : une petite file d'attente maison, ou la
  bibliothèque ChatThrottleLib si on accepte une dépendance.

### Étapes
1. Vérifier sur WoW Forever : `C_ChatInfo.SendAddonMessage`, le filtre de
   messages du chat, et l'interception des clics sur les liens.
2. Protocole d'addon : demande / réponse en morceaux / file à cadence limitée,
   avec un numéro de version dans chaque message.
3. Fenêtre d'aperçu réutilisable (aussi pour l'import de code et le catalogue).
4. « Lier dans le chat » + affichage du lien + clic → demande → aperçu.
5. Onglet Guilde : publication opt-in, liste, cache.

### Questions ouvertes
- WoW Forever autorise-t-il les messages d'addon en chuchotement entre
  royaumes, ou seulement sur le même royaume ?
- Faut-il limiter le nombre de macros publiées par joueur pour garder le canal
  de guilde léger (par exemple 20) ?
- Signalement ou masquage d'un auteur dans l'onglet Guilde ?

**Effort estimé** : important (protocole réseau, interception du chat, tests à
plusieurs comptes).

---

## Briques communes à prévoir
- **Fenêtre d'aperçu** (nom, icône, explication, avertissements, Importer) :
  sert aux modèles, au catalogue, aux liens de chat et à l'import de code.
- **Format de code `BM2!` transportant les blocs** : nécessaire pour partager
  des modèles à trous et des packs de modèles. Le `BM1!` reste lisible.
