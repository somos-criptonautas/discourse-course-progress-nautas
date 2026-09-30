# Discourse Course Progress — Fork de Criptonautas

[ENGLISH](README.md) | **ESPAÑOL**

Plugin de Discourse del lado del servidor que devuelve el **estado de lectura histórico real** de los temas por usuario, para la progresión de cursos tipo LMS. Fork de [zsviczian/discourse-course-progress](https://github.com/zsviczian/discourse-course-progress) (MIT).

## Qué añade este fork

**Navegación Anterior / Siguiente entre temas** para Doc Categories:

- Renderiza enlaces **Anterior / Siguiente** al final del post de la lección, **antes de cualquier respuesta**, tanto en el flujo plano de posts como en la vista de respuestas anidadas, con estilo de pareja de tarjetas para que se lean como navegación del curso y no como parte de la lista de temas sugeridos.
- Lee el índice ordenado que el plugin oficial **Doc Categories** ya serializa en la categoría (`doc_category_index`), sin llamadas extra a la API.
- Limitado a la categoría que tiene el Index Topic. Sus **subcategorías son categorías normales**: listado normal, sin Anterior / Siguiente, sin barra lateral de docs.
- Reconoce tanto enlaces relativos a la raíz (`/t/slug/1`) como absolutos (`https://host/t/slug/1`) en el Index Topic.
- Se oculta automáticamente en temas fuera del índice (por ejemplo, el propio Index Topic).
- Las etiquetas están localizadas (`en`, `es`) y llevan iconos `arrow-left` / `arrow-right`, que el componente [Phosphor duotone](https://github.com/somos-criptonautas/discourse-phosphor-duotone-icons) sustituye automáticamente por los suyos.
- Componente Glimmer registrado con `renderAfterWrapperOutlet("post-links")` y mostrado solo en el post #1; estilos acotados bajo `.course-doc-nav`, sobrescribibles desde cualquier tema. También visible para visitantes anónimos.

**Marcadores de progreso en la barra lateral.** Un contador atenuado `leídos/total` junto a las categorías
de curso en la barra lateral principal, y un punto en cada lección ya leída en la barra
lateral de Docs, en sustitución del componente de tema complementario (ver *Interfaz de progreso*).

**Alcance de la barra lateral de Docs.** Doc Categories resuelve el índice de una categoría recorriendo
el árbol de categorías hacia arriba, así que toda subcategoría de una categoría de docs hereda su
barra lateral. Este fork detiene ese recorrido: la barra lateral aparece solo en la categoría
que realmente tiene configurado un Index Topic.

Funciona declarando `before: "doc-categories"` en el inicializador, porque Doc Categories
instancia el servicio de la barra lateral en la primera línea de su propio inicializador y una
clase parcheada después de ese punto se ignora (Discourse registra una advertencia indicándolo).

Se implementa sobrescribiendo el getter `activeCategory` del servicio de la barra lateral: el método privado
`#findIndexForActiveCategory` que hace el recorrido no se puede parchear, pero el getter que lee sí,
así que devolver nada para una categoría sin su propio `doc_category_index` termina el recorrido antes de que empiece.

Esto se aplica a las páginas de listado de subcategorías y a los temas dentro de ellas, que es el
comportamiento buscado: una subcategoría de una categoría de docs es una categoría normal
y debe verse como tal. Desactívalo con el ajuste del sitio
`course_progress_docs_sidebar_only_on_index_category`.

## Ajustes del sitio

Todo el comportamiento de este fork se puede activar o desactivar desde **Admin → Plugins → Course
Progress Nautas**, o desde **Admin → Ajustes** buscando `course_progress`.
Son ajustes de plugin, no ajustes de tema.

El `# name:` del plugin en `plugin.rb` es `discourse-course-progress-nautas` y
debe seguir coincidiendo con el directorio en el que se clona. El núcleo lee los ajustes de
`plugins/<directorio>/config/settings.yml` y los archiva bajo el nombre del directorio,
mientras que la página de administración los busca por el nombre declarado del plugin; cuando
ambos difieren los ajustes siguen funcionando, pero la página de administración del plugin no lista
ninguno.

(Discourse no renderiza página de administración para un plugin cuyo único ajuste es su propio
interruptor de activación; ver `Plugin::Instance#has_only_enabled_setting?`. Este fork tiene
cinco, así que la página se muestra.)

| Ajuste | Por defecto | Qué hace |
| --- | --- | --- |
| `course_progress_enabled` | on | Interruptor general del endpoint y de todo lo siguiente. |
| `course_progress_doc_navigation_enabled` | on | Los enlaces Anterior / Siguiente. |
| `course_progress_docs_sidebar_only_on_index_category` | on | Evita que las subcategorías hereden la barra lateral de docs. |
| `course_progress_sidebar_markers_enabled` | on | Los contadores leídos/total y los puntos de leído en la barra lateral. |
| `course_progress_non_course_topics` | 0 | Temas a descontar del contador de la barra lateral (ver *Interfaz de progreso*). |

## Por qué existe

El motor de notificaciones de Discourse oculta los temas creados antes de la cuenta de un usuario, así que los scripts del lado del cliente no pueden seguir el progreso de lectura histórico. Este plugin consulta directamente la tabla `TopicUser`, sin pasar por ese motor.

## Dependencias

- El plugin oficial **Discourse Docs**, con un **Index Topic** configurado en la categoría (ajustes de Docs).

## Instalación

1. Entra por SSH a tu servidor de Discourse y edita `app.yml`.
2. Añade la URL de clonado bajo `hooks`, debajo de `docker_manager`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/somos-criptonautas/discourse-course-progress-nautas.git
```

3. Reconstruye: `cd /var/discourse && ./launcher rebuild app`

## Interfaz de progreso

Los marcadores de progreso los dibuja este plugin: **el componente de tema complementario
[discourse-course-progress-theme](https://github.com/zsviczian/discourse-course-progress-theme)
ya no es necesario y debe desinstalarse**, o ambos conjuntos de marcadores se renderizan
uno junto al otro.

- **Las categorías de curso en la barra lateral principal** reciben un contador atenuado `leídos/total` y
  una marca de verificación cuando todas las lecciones están leídas.
- **Las lecciones en la barra lateral de Docs** reciben la misma marca una vez leídas, y nada
  antes.

Una marca en lugar de un punto: un punto de color en una fila de la barra lateral ya significa contenido
sin leer en Discourse, así que reutilizarlo para el estado opuesto se lee mal.

Los marcadores usan el propio espacio de insignia del núcleo (`.sidebar-section-link-content-badge`),
que el núcleo ya empuja al final de la fila y recorta con puntos suspensivos, de modo que la fila
conserva intactos los estilos de hover y activo del núcleo. El componente de tema, en cambio,
forzaba `display: flex` / `width: 100%` / `padding-right` sobre el enlace, lo que
sacaba el resaltado de la alineación con las filas vecinas.

El parámetro `non_course_files` del tema sigue existiendo como
`course_progress_non_course_topics`, pero ahora vale **0** por defecto: este fork
ya excluye en el servidor el Index Topic y el tema "Acerca de esta categoría". Súbelo solo cuando un índice liste temas que no son lecciones (un
post de bienvenida, unas preguntas frecuentes) y el contador deba ignorarlos. Afecta solo al contador de la barra lateral;
`/course-progress.json` sigue informando del total real.

Cada marcador lleva un `title` localizado (`en`, `es`), así que el contador y
la marca son legibles al pasar el cursor y para lectores de pantalla.

Desactiva los marcadores con `course_progress_sidebar_markers_enabled`. Los estilos están
acotados bajo `.course-progress-badge` y son sobrescribibles desde cualquier tema.

## API

`GET /course-progress.json`: solo usuarios con sesión iniciada (los invitados no tienen historial de lectura).

```json
{
  "courses": {
    "36": {
      "total_topics": 69,
      "read_count": 66,
      "read_topic_ids": [502, 503, 504]
    }
  }
}
```

Los totales salen del **Index Topic**, no de un escaneo directo de la categoría, así que los
números cuentan exactamente las lecciones que lista el índice y coinciden con la navegación
Anterior / Siguiente. El propio Index Topic queda
**excluido**: es navegación, no contenido del curso, así que un curso de 10 lecciones
informa `total_topics: 10`.

Todo está limitado a los permisos del usuario que hace la petición: las categorías restringidas
y los temas eliminados o ilegibles nunca aparecen. Si el Index Topic de un curso
nunca se ha analizado, el endpoint recurre a escanear la categoría directamente
(sin subcategorías) en lugar de informar cero.

## Insignias de finalización (opcional)

Nada de esto es obligatorio para el plugin, y nada es código del plugin: es una
receta para las insignias SQL personalizadas del núcleo de Discourse, que pueden leer las mismas tablas de Doc
Categories que lee el endpoint y que otorgan y revocan por sí solas.
Los sitios que no quieran insignias de finalización pueden saltarse esta sección por completo.

Las insignias SQL están detrás de un ajuste oculto del sitio, que se activa desde la consola de Rails:

```
SiteSetting.enable_badge_sql = true
```

Luego una insignia por curso y por hito, con el disparador en **actualizar
a diario**. `i.category_id` selecciona el curso y el umbral final selecciona el
hito: `1.0` para finalización completa, `0.30` / `0.50` / `0.70` para progreso
parcial:

```sql
WITH lessons AS (
  SELECT DISTINCT l.topic_id
  FROM doc_categories_indexes i
  JOIN doc_categories_sidebar_sections s ON s.index_id = i.id
  JOIN doc_categories_sidebar_links l ON l.sidebar_section_id = s.id
  JOIN topics t ON t.id = l.topic_id AND t.deleted_at IS NULL
  WHERE i.category_id = 41
    AND l.topic_id <> i.index_topic_id
),
progress AS (
  SELECT tu.user_id,
         COUNT(DISTINCT tu.topic_id)::numeric
           / NULLIF((SELECT COUNT(*) FROM lessons), 0) AS ratio,
         MAX(tu.last_visited_at) AS at
  FROM topic_users tu
  JOIN lessons ON lessons.topic_id = tu.topic_id
  WHERE tu.last_read_post_number >= 1
  GROUP BY tu.user_id
)
SELECT user_id, COALESCE(at, CURRENT_TIMESTAMP) AS granted_at
FROM progress
WHERE ratio >= 0.30
```

La consulta sigue la misma definición de lección que el endpoint: los temas
que lista el Index Topic, menos el propio Index Topic y los temas eliminados.

Notas que conviene conocer antes de desplegar esto:

- **Los hitos se acumulan.** Un miembro conserva todos los hitos alcanzados, ya que Discourse
  no tiene exclusión mutua entre insignias. Acotar las consultas inferiores
  (`ratio >= 0.30 AND ratio < 0.50`) muestra solo la más alta, a costa de que
  las insignias desaparezcan a medida que los miembros avanzan.
- **La revocación automática está activada por defecto.** Añadir una lección a un índice baja el ratio de todos
  los miembros, y la siguiente ejecución diaria retira la insignia hasta que la
  lean. Los sitios que traten la finalización como permanente deben desactivar la revocación automática por
  insignia.
- **Las concesiones son diarias.** El núcleo no dispara ningún evento cuando se lee un tema, así que el retraso
  entre terminar un curso y recibir la insignia es de hasta una ejecución del
  trabajo diario de relleno.
- **Los MP al otorgar** son trabajo del plugin Automation del núcleo: el disparador **User badge
  granted** (con *only first grant* marcado, para que una revocación y reconcesión
  pase en silencio) junto con el script **Send PMs**.

## Solución de problemas

**No aparecen los enlaces Anterior / Siguiente.** El plugin Doc Categories solo expone
el índice ordenado (`doc_category_index`) cuando su estructura de barra lateral se ha
construido, lo que ocurre en un trabajo en segundo plano cuando el Index Topic se **edita o
reasigna**. En un curso configurado antes de que existiera ese mecanismo,
basta con volver a guardar el Index Topic (edítalo y guarda, o vuelve a elegirlo en los
ajustes de Docs de la categoría).

**Falta una lección en la lista Anterior / Siguiente.** El analizador de Doc Categories
solo recoge enlaces dentro de un elemento de lista `<ul>`/`<ol>` en el primer post del
Index Topic; todo lo demás se ignora. Vuelve a guardar el Index Topic tras
corregirlo.

## Pruebas

```
node test/topic-href.test.mjs
```

## Licencia

MIT (upstream: zsviczian). Modificaciones © 2026 Criptonautas. Consulta [LICENSE](LICENSE).

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
