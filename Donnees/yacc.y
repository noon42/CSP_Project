%{
#include "arbre.h"
#include "variable.h"
#include "backtrack.h"
#include <unistd.h>
    
extern int yylex(); /* pour supprimer un warning */
extern int yyerror(); /* pour supprimer un warning */
extern FILE* yyin; /* pour remplacer stdin par un fichier */
extern void yylex_destroy();

extern FILE* fileToWrite;

extern int num_ligne; // recouvre la variable num_ligne du fichier lex.l

listeContrainte listeContraintes;

variables listeVariables; // la grande liste de toutes les variables
variables variablesPartageantDomaine; // une sous liste des variables ayant le meme domaine. cette liste contiendra pendant l'analyse chaque liste ayant un domaine
variables variablesAlldiff; // stocke les variables d'un alldiff pour pouvoir ajouter les contraintes != entre chaque couple de cette liste
domaine domaineVariable; // ce domaine contiendra pendant l'analyse chaque domaine communs aux variables dans variablePartageantDomaine
domaine domaineVariable2;
; // ce domaine est utile pour en faire l'union avec le premier. c'est dans celui ci qu'on ajoute les valeurs. puis en fin d'ajout, on fait l'union entre le premier et le deuxieme qu'on stocke dans le premier
pile_domaines listeDomaines; // comme un domaine peut etre commun a plusieurs variable, la liberation d'un domaine ne peut se faire avec la liberation d'une variable. on stock tous les domaines dans cette liste pour tous les vider correctement en fin du programme

variable* var;



int nombreVariable = 0;
int indiceVariable;

char* presenceVariable; // chaine de 0 et 1. si presenceVariable[i] == 1, alors il y a la variable d'indice i dans l'arbre de la contrainte, sinon elle n'y est pas

%}

%union
{
    arbre arbre;
    float valeur;
    char* chaine;
}

%type <chaine> IDF

%type <valeur> ENTIER REEL BOOLEEN

%type <arbre> fonction nombre expression7 expression6 expression5 expression4 expression3 expression2 expression1 expression

%token XD C
%token VIRGULE DEUX_POINTS POINT_POINT
%token PO PF CO CF AO AF
%token UNION ALLDIFF
%token PLUS MOINS MULTIPLIE_PAR DIVISE_PAR MODULO
%token ET OU NON EGAL DIFFERENT SUPERIEUR_OU_EGAL INFERIEUR_OU_EGAL SUPERIEUR INFERIEUR
%token ENTIER REEL BOOLEEN
%token SQRT SIN COS TAN
%token IDF ERREUR

%%
programme:
XD liste_var_dom C liste_contraintes
;

liste_var_dom:
var_dom liste_var_dom
| var_dom
;

var_dom:
{// on est juste avant l'analyse d'une liste de variable partageant un domaine. On creer donc la liste des variables partageant ce domaine ainsi que ce domaine
    variablesPartageantDomaine = creer_liste_var_vide();
    domaineVariable = creer_domaine();
    domaineVariable2 = creer_domaine();
}
liste_variables DEUX_POINTS union_domaine
{ // on est juste apres l'analyse des variables partageant un domaine. le domaine est plein et la liste des variables l'utilisant aussi. il faut donc ratacher ce domaine a ces variables, puis mettre ce sous ensemble des variables du CSP dans l'ensemble des variables du CSP
    affecterDommaineDansVariables(variablesPartageantDomaine, domaineVariable); // ratachement du domaine a toutes les variable l'utilisant
    concat_variables(&listeVariables, &variablesPartageantDomaine); // on rajoute ce sous ensemble de variable dans l'ensemble des variable
}
;

liste_variables:
IDF VIRGULE liste_variables
{ // si on trouve une variable, il faut l'ajouter au sous ensemble des variables et augmenter le nombre de variables
    variablesPartageantDomaine = ajouter_var(variablesPartageantDomaine, $1); // ajoute la variable en donnant son nom en parametre
    nombreVariable++; // augmente le nombre de variable
}
| IDF
{ // pareil que juste au dessus
    variablesPartageantDomaine = ajouter_var(variablesPartageantDomaine, $1); 
    nombreVariable++;
}
;

union_domaine:
domaine UNION union_domaine
{ // on est juste apres l'analyse d'un domaine, on doit faire l'union entre celui qu'on vient de construire, et celui qu'on avait auparavant
    empiler(&listeDomaines, domaineVariable2); // on ajoute ce domaine a la liste des domaines juste pour garder la trace des domaines a supprimer en fin du programme
    domaineVariable = union_domaine(domaineVariable, domaineVariable2);
    domaineVariable2 = creer_domaine(); // on refait un nouveau domaine vide si jamais on en rencontre un autre par la suite
}
| domaine
{ // pareil qu'au dessus
    empiler(&listeDomaines, domaineVariable2);
    domaineVariable = union_domaine(domaineVariable, domaineVariable2);
    domaineVariable2 = creer_domaine();
}
;

domaine:
AO liste_entiers AF
| intervalle
;

liste_entiers:
ENTIER VIRGULE liste_entiers
{// on trouve un entier a ajouter dans le domaine, donc on l'ajoute
    ajouter_valeur(&domaineVariable2, $1);
}
| ENTIER
{// pareil qu'au dessus
    ajouter_valeur(&domaineVariable2, $1);
}
;

intervalle:
CO ENTIER POINT_POINT ENTIER CF
{ // on trouve le domaine est un intervalle donc on initialise le domain a cet interval
    domaineVariable2 = initialiser($2, $4); // initialise le domaine entre la borne inferieur et la borne superieur
}
;








liste_contraintes:
contrainte liste_contraintes
| contrainte
;

contrainte:
{ // on est sur le point d'analyser une contraintes, on creer son tableau de presence des variables en l'initialisant
    presenceVariable = creerTableauPresenceVariable(nombreVariable);
}
expression
{ // on a fini d'analyser la contrainte. on ajoute un maillon dans la liste des contraintes pour celle-ci en donnant son arbre et son tableau de presence des variables
    ajouter_contrainte(&listeContraintes, $2, presenceVariable);
}
| ALLDIFF
{
    variablesAlldiff = creer_liste_var_vide();
}
PO liste_variables_alldiff PF
{
    liberer_liste(variablesAlldiff);
}
;

liste_variables_alldiff:
IDF VIRGULE liste_variables_alldiff
{ // si on trouve une nouvelle variable dans le ALLDIFF, on doit ajouter les contraintes different entre cette nouvelle variable et toutes les autres precedement rencontree (qu'on stocke dans la liste variablesAlldiff)
    ajouterContraintesDifferent($1, variablesAlldiff, &listeContraintes, listeVariables, nombreVariable);
    variablesAlldiff = ajouter_var(variablesAlldiff, $1);
}
| IDF
{
    ajouterContraintesDifferent($1, variablesAlldiff, &listeContraintes, listeVariables, nombreVariable);
    variablesAlldiff = ajouter_var(variablesAlldiff, $1);
}
;


expression:
expression1
{
    $$ = $1;
}
| expression OU expression1
{
    $$ = attache_papa_fils(cons_noeud(A_OU, NULL), attache_papa_frangin($1, $3));
}
;

expression1:
expression2
{
    $$ = $1;
}
| expression1 ET expression2
{
    $$ = attache_papa_fils(cons_noeud(A_ET, NULL), attache_papa_frangin($1, $3));
}
;

expression2:
expression3
{
    $$ = $1;
}
| expression2 EGAL expression3
{
    $$ = attache_papa_fils(cons_noeud(A_EGAL, NULL), attache_papa_frangin($1, $3));
}
| expression2 DIFFERENT expression3
{
    $$ = attache_papa_fils(cons_noeud(A_DIFFERENT, NULL), attache_papa_frangin($1, $3));
}
;

expression3:
expression4
{
    $$ = $1;
}
| expression3 SUPERIEUR_OU_EGAL expression4
{
    $$ = attache_papa_fils(cons_noeud(A_SUPERIEUR_OU_EGAL, NULL), attache_papa_frangin($1, $3));
}
| expression3 INFERIEUR_OU_EGAL expression4
{
    $$ = attache_papa_fils(cons_noeud(A_INFERIEUR_OU_EGAL, NULL), attache_papa_frangin($1, $3));
}
| expression3 SUPERIEUR expression4
{
    $$ = attache_papa_fils(cons_noeud(A_SUPERIEUR, NULL), attache_papa_frangin($1, $3));
}
| expression3 INFERIEUR expression4
{
    $$ = attache_papa_fils(cons_noeud(A_INFERIEUR, NULL), attache_papa_frangin($1, $3));
}
;

expression4:
expression5
{
    $$ = $1;
}
| expression4 PLUS expression5
{
    $$ = attache_papa_fils(cons_noeud(A_PLUS, NULL), attache_papa_frangin($1, $3));
}
| expression4 MOINS expression5
{
    $$ = attache_papa_fils(cons_noeud(A_MOINS, NULL), attache_papa_frangin($1, $3));
}
;

expression5:
expression6
{
    $$ = $1;
}
| expression5 MULTIPLIE_PAR expression6
{
    $$ = attache_papa_fils(cons_noeud(A_MULTIPLIE_PAR, NULL), attache_papa_frangin($1, $3));
}
| expression5 DIVISE_PAR expression6
{
    $$ = attache_papa_fils(cons_noeud(A_DIVISE_PAR, NULL), attache_papa_frangin($1, $3));
}
| expression5 MODULO expression6
{
    $$ = attache_papa_fils(cons_noeud(A_MODULO, NULL), attache_papa_frangin($1, $3));
}
;

expression6:
expression7
{
    $$ = $1;
}
| NON PO expression PF
{
    $$ = attache_papa_fils(cons_noeud(A_NON, NULL), $3);
}
;

expression7:
PO expression PF
{
    $$ = $2;
}
| nombre
{
    $$ = $1;
}
| IDF
{ // si on trouve une variable dans l'arbre contraintes, il faut dire que cette contrainte apparait dans le tableau presence, et il faut creer un noeud en donant un pointeur sur sa valeur
    var = retournerVariablePortantNom(listeVariables, $1, &indiceVariable); // on chope un pointeur sur la variable de ce nom (et au passage on recupere son indice)
    presenceVariable[indiceVariable] = '1'; // il faut dire que cette variable est presente dans cette contraintes, donc on met a 1 son indice dans le tableau de presence
    $$ = cons_noeud(A_IDF, &(var->valeur)); // le deuxieme parametre est le pointeur sur la valeur de la variable ayant le nom de l'IDF
    free($1); // $1 vien d'un appel a strdup dans le fichier lex, il ne faut pas oublier de le liberer
}
| fonction
{
    $$ = $1;
}
;

fonction:
SQRT PO expression4 PF
{
    $$ = attache_papa_fils(cons_noeud(A_SQRT, NULL), $3);
}
| SIN PO expression4 PF
{
    $$ = attache_papa_fils(cons_noeud(A_SIN, NULL), $3);
}
| COS PO expression4 PF
{
    $$ = attache_papa_fils(cons_noeud(A_COS, NULL), $3);
}
| TAN PO expression4 PF
{
    $$ = attache_papa_fils(cons_noeud(A_TAN, NULL), $3);
}
;

nombre:
ENTIER
{
    $$ = cons_noeud(A_ENTIER, NULL);
    *($$->valeur) = $1;
}
| REEL
{
    $$ = cons_noeud(A_REEL, NULL);
    *($$->valeur) = $1;
}
| BOOLEEN
{
    $$ = cons_noeud(A_BOOLEEN, NULL);
    *($$->valeur) = $1;
}
;

%%
int yyerror()
{
    fprintf(fileToWrite,"Erreur de syntaxe ligne %d\n", num_ligne);
    return 0;
}

void usage(char* prog){
	fprintf(fileToWrite, "Usage : %s [-a nombre] [-o fichier_où_ecrire] [-s] [-t nombre] [-v] [-z] fichier_contenant_le_CSP\n", prog);
	fprintf(fileToWrite, "\t-a nombre : permet d'utiliser l'algorithme de numéro nombre, nombre peut prendre plusieurs valeurs :\n");
	fprintf(fileToWrite, "\t\t1 : l'algorithme utilisé sera l'algorithme de backtrack (comportement de base si l'option n'est pas renseignée)\n");
	fprintf(fileToWrite, "\t\tTO DO\n");
	fprintf(fileToWrite, "\t-o fichier_où_ecrire : le résultat du CSP sera écrit dans le fichier fichier_où_ecrire\n");
	fprintf(fileToWrite, "\t-s : active le mode silence\n");
	fprintf(fileToWrite, "\t-t nombre : permet de résoudre le CSP de numéro nombre, nombre peut prendre plusieurs valeurs :\n");
	fprintf(fileToWrite, "\t\t1 : le CSP résolu sera un CSP classique (comportement de base si l'option n'est pas renseignée)\n");
	fprintf(fileToWrite, "\t\t2 : le CSP résolu sera un sudoku\n");
	fprintf(fileToWrite, "\t\tTO DO\n");
	fprintf(fileToWrite, "\t-v : affiche la liste des variables\n");
	fprintf(fileToWrite, "\t-z : affiche les contributeurs du programme\n");
	exit(EXIT_FAILURE);
}

		char c;
		char* fileName;

		int afficherContributeur = 0;
		int algorithmeUtilise = 1;
		int ecrireDansFichier = 0;
		int listeVariable = 0;

int main(int argc, char* argv[])
{
/* TO DO :
* gérer les types de CSP
*/
		
		fileToWrite = stderr;
		typeCSP = 1;
		modeSilence = 0;
		opterr = 0; //on bloque les messages d'erreurs de getopt
		
		while((c = getopt(argc, argv, "a:o:st:vz")) != -1){
			switch (c) {
			case 'a':
				algorithmeUtilise = atoi(optarg);
				break;
			case 'o':
				ecrireDansFichier++;
				fileToWrite = fopen(optarg, "w");
				break;
			case 's':
				modeSilence++;
				break;
			case 't':
				typeCSP = atoi(optarg);
				break;
			case 'v':
				listeVariable++;
				break;
			case 'z' :
				afficherContributeur++;
				break;
			default:
				usage(argv[0]);
			}
		}
		
		if (optind < argc)
			fileName = argv[optind];
		else{
			usage(argv[0]);
		}

        // initialisations
    listeVariables = creer_liste_var_vide();
    domaineVariable2 = creer_domaine();
    listeContraintes = creer_liste_contrainte();
    listeDomaines = creer_pile_domaines();

        //analyse du fichier
    yyin=fopen(fileName, "r"); /* ouverture du fichier contenant le CSP */
    yyparse();
    fclose(yyin);

    affecterContraintesDansVariables(listeVariables, &listeContraintes, nombreVariable);
    initialiserValeurVariables(listeVariables);
    
        // affichage resultat
		if(listeVariable)
	    afficher_liste(listeVariables);
    

    initialiserValeurVariables(listeVariables);

    
    switch(algorithmeUtilise){
			case 1 :
	resolutionBacktrackUneSolution(listeVariables);
				break;
                        case 2:
	resolutionBacktrackToutesSolutions(listeVariables);
				break;
			default :
				fprintf(fileToWrite, "Numero d'algo de resolution inconnu\n");
				usage(argv[0]);
    }
    

		if(afficherContributeur)
			//afficherContributeur();

        // vidages
    vider_pile_domaines(listeDomaines);
    liberer_liste(listeVariables);
    yylex_destroy();
    return EXIT_SUCCESS;
}
