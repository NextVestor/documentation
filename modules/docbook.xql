xquery version "3.0";

module namespace docbook="http://docbook.org/ns/docbook";

import module namespace config="http://exist-db.org/xquery/apps/config" at "xmldb:exist:///db/doc/modules/config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
import module namespace dq="http://exist-db.org/xquery/documentation/search" at "search.xql";

declare variable $docbook:INLINE := 
    ("filename", "classname", "methodname", "option", "command", "parameter", "guimenu", "guimenuitem", "guibutton", "function", "envar");
(:~
 : Load a docbook document. If a query was specified, re-run the query on the document
 : to get matches highlighted.
 :)
declare 
    %public %templates:default("field", "all")
function docbook:load($node as node(), $model as map(*), $q as xs:string?, $doc as xs:string?, $field as xs:string) {
    let $path := $config:data-root || "/" || $doc
    return
        if (exists($doc) and doc-available($path)) then
            let $context := doc($path)
            let $data :=
                if ($q) then
                    dq:do-query($context, $q, $field)
                else
                    $context
            return
                map { "doc" := util:expand($data/*, "add-exist-id=all") }
        else
            <p>Document not found: {$path}!</p>
};

(:~
 : Transform the docbook fragment given in $model.
 :)
declare %public function docbook:to-html($node as node(), $model as map(*)) {
    docbook:to-html($model("doc"))
};

(:~
 : Generate a table of contents.
 :)
declare %public function docbook:toc($node as node(), $model as map(*)) {
    <div>
        <h3>Contents</h3>
        {
        docbook:print-sections($model("doc")/*/(chapter|section))
        }
    </div>
};

declare %private function docbook:print-sections($sections as element()*) {
    if ($sections) then
        <ul class="toc">
        {
            for $section in $sections
            let $id := if ($section/@id) then $section/@id else concat("D", $section/@exist:id)
            return
                <li>
                    <a href="#{$id}">{ $section/title/text() }</a>
                    { docbook:print-sections($section/(chapter|section)) }
                </li>
        }
        </ul>
    else
        ()
};

declare %private function docbook:to-html($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                docbook:to-html($node/*)
            case element(book) return
                <article>
                    {docbook:process-children($node/chapter)}
                    {docbook:print-authors($node)}
                </article>
            case element(article) return
                <article>
                    {docbook:process-children($node/section)}
                    {docbook:print-authors($node)}
                </article>
            case element(chapter) return
                <section>
                {docbook:process-children($node)}
                </section>
            case element(section) return
                <section>
                    <a name="D{$node/@exist:id}"></a>
                    {docbook:process-children($node)}
                </section>
            case element(abstract) return
                <blockquote>{docbook:process-children($node)}</blockquote>
            case element(title) return
                let $level := count($node/(ancestor::chapter|ancestor::section))
                return
                    element { "h" || $level } {
                        if ($level = 1) then
                            attribute class { "front-title" }
                        else
                            (),
                        if ($node/../@id) then
                            <a name="{$node/../@id}"></a>
                        else
                            <a name="D{$node/../@exist:id}"></a>,
                        docbook:process-children($node)
                    }
            case element(para) return
                if ($node/parent::listitem and not($node/preceding-sibling::para or $node/following-sibling::para)) then
                    docbook:process-children($node)
                else
                    <p>{docbook:process-children($node)}</p>
            case element(emphasis) return
                <em>{docbook:process-children($node)}</em>
            case element(itemizedlist) return
                <ul>{docbook:to-html($node/listitem)}</ul>
            case element(listitem) return
                if ($node/parent::varlistentry) then
                    docbook:process-children($node)
                else
                    <li>{docbook:process-children($node)}</li>
            case element(variablelist) return
                <dl class="dl-horizontal">{docbook:process-children($node)}</dl>
            case element(varlistentry) return (
                <dt><p>{docbook:process-children($node/term)}</p></dt>,
                <dd>{docbook:to-html($node/listitem)}</dd>
            )
            case element(figure) return
                docbook:figure($node)
            case element(screenshot) return
                docbook:figure($node)
            case element(example) return
                docbook:figure($node)
            case element(screen) return
                docbook:code($node)
            case element(graphic) return
                let $align := $node/@align
                let $class := if ($align) then "float-" || $align else ""
                return
                    <img src="{$node/@fileref}"/>
            case element(imagedata) return
                let $align := $node/@align
                let $class := if ($align) then "float-" || $align else ""
                return
                    <img src="{$node/@fileref}"/>
            case element(ulink) return
                <a href="{$node/@url}">{docbook:process-children($node)}</a>
            case element(note) return
                <div class="alert alert-success">
                    <h2>Note</h2>
                    { docbook:process-children($node) }
                </div>
            case element(important) return
                <div class="alert alert-error">
                    <h2>Important</h2>
                    { docbook:process-children($node) }
                </div>
            case element(synopsis) return
                docbook:code($node)
            case element(programlisting) return
                docbook:code($node)
            case element(procedure) return
                <div class="procedure">
                    <ol>
                    {docbook:process-children($node)}
                    </ol>
                </div>
            case element(step) return
                <li>{docbook:process-children($node)}</li>
            case element(filename) return
                <code style="font-size:smaller; line-height:inherit">{docbook:process-children($node)}</code>
            case element(toc) return
                <ul class="toc">
                {docbook:process-children($node)}
                </ul>
            case element(tocpart) return
                <li>{docbook:process-children($node)}</li>
            case element(tocentry) return
                docbook:process-children($node)
            case element(exist:match) return
                <span class="hi">{$node/text()}</span>
            case element() return
                let $name := local-name($node)
                return
                    if ($name = $docbook:INLINE) then
                        <span class="{local-name($node)}">{docbook:process-children($node)}</span>
                    else
                        element { node-name($node) } {
                            $node/@*,
                            docbook:process-children($node)
                        }
            case text() return
                $node
            default return
                ()
};

declare %private function docbook:inline($node as node()) {
    <span class="{local-name($node)}">{docbook:process-children($node)}</span>
};

declare %private function docbook:figure($node as node()) {
    <figure>
        {docbook:to-html($node/*[not(self::title)])}
        {
            if ($node/title) then
                <figcaption>{$node/title/text()}</figcaption>
            else
                ()
        }
    </figure>
};

declare %private function docbook:code($elem as element()) {
    let $lang := 
        if ($elem//markup) then
            "xml"
        else if ($elem/@language) then
            $elem/@language
        else
            ()
    return
        if ($lang) then
            <div class="code" data-language="{$lang}">
            { replace($elem/string(), "^\s+", "") }
            </div>
        else
            <pre>{ replace($elem/string(), "^\s+", "") }</pre>
};

declare %private function docbook:process-children($elem as element()) {
    for $child in $elem/node()
    return
        docbook:to-html($child)
};

declare %private function docbook:print-authors($root as element()) {
    <div class="authors">
    {
        for $author in $root/bookinfo/author
        return
            <address>
                <strong>{$author/firstname} {$author/surname}</strong>
                { for $jobtitle in $author/jobtitle return (<br/>, $author/jobtitle/text()) }
                { for $orgname in $author/orgname return (<br/>, $author/orgname/text()) }
                { for $email in $author/email return (<br/>, <a href="mailto:{$author/email}">{$author/email/text()}</a>) }
            </address>
    }
    </div>
};