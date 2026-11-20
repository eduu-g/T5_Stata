# T5 --- Do-file automatizado

Do-file en Stata que automatiza la preparación y el análisis descriptivo
y econométrico de la base CASEN reducida, utilizando macros, ciclos y un
programa reutilizable. También estima modelos por sector y exporta sus
resultados.

## Datos

Se utiliza la base `casen_reducido.csv`, correspondiente a 60
observaciones y ubicada en `data/raw/casen_reducido.csv`.

El do-file importa los datos, genera las variables `experiencia` y
`mujer`, calcula estadísticas descriptivas, estima modelos de regresión
y realiza estimaciones separadas por sector.

## Cómo correrlo

1.  Abrir Stata.
2.  Establecer como directorio de trabajo la carpeta principal del
    proyecto (`T5_Stata`).
3.  Abrir `scripts/tarea_t5.do`.
4.  Ejecutar el do-file completo.

El programa utiliza rutas relativas, por lo que debe ejecutarse desde la
carpeta principal del proyecto. Los resultados se generan en la carpeta
`output/`.

Para reutilizar el do-file con otros datos o configuraciones, se deben
revisar los parámetros al inicio del archivo:

-   `datos`: ruta del archivo de datos.
-   `depvar`: variable dependiente de las regresiones.
-   `numericas`: lista de variables para las estadísticas descriptivas.
-   `controles`: variables explicativas incluidas en los modelos.
-   `grupos`: variables utilizadas para los descriptivos por grupo.
-   `umbral`: valor mínimo utilizado en el filtro de ingresos.

La prueba de parametrización se realiza modificando un parámetro en ese
bloque y ejecutando nuevamente el do-file completo. Por ejemplo, al
cambiar `umbral`, se actualiza el conteo de observaciones que superan
ese valor.

## Resultados

Al ejecutar el do-file se generan los siguientes archivos:

-   `output/tarea_t5.log`: registro de la ejecución y de los resultados
    mostrados por Stata.
-   `output/tarea_t5_por_sector.xlsx`: tabla con el coeficiente de
    educación, su error estándar y el número de observaciones de cada
    regresión por sector.

## Estructura

``` text
T5_Stata/
├── data/
│   └── raw/
│       └── casen_reducido.csv
├── scripts/
│   └── tarea_t5.do
├── output/
│   ├── tarea_t5.log
│   └── tarea_t5_por_sector.xlsx
└── README.md
```

## Autor

Eduardo Guerrero --- noviembre de 2026

```markdown
## Declaración de autoría y uso de IA
- Herramienta utilizada: ChatGPT
- Para qué la usé: Entender algunos codigos y funcionamiento de STATA, Orden y ayudas de ortografia,
ayuda con la redacción del README
- Qué hice yo: Escritura de codigo y analisis e interpretación
- Verificación: confirmo que entiendo y puedo explicar todo lo que entrego.
```
